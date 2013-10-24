#pragma rtGlobals=1		// Use modern global access method.
#pragma version=5.0
#pragma IgorVersion=6.1

//simple, main entry procedure that will load a RAW sans data file (not a work file)
//into the RAW dataFolder. It is up to the calling procedure to display the file
//
// called by MainPanel.ipf and ProtocolAsPanel.ipf
//
Function LoadRawSANSData(msgStr)
	String msgStr

	String filename = ""

	//each routine is responsible for checking the current (displayed) data folder
	//selecting it, and returning to root when done
	PathInfo/S catPathName		//should set the next dialog to the proper path...
	//get the filename, then read it in
	filename = PromptForPath(msgStr)//in SANS_Utils.ipf
	
	//check for cancel from dialog
	if(strlen(filename)==0)
		//user cancelled, abort
		SetDataFolder root:
		DoAlert 0, "No file selected, action aborted"
		return(1)
	Endif
	
	Variable t1=ticks
	
	variable error
	ReadHeaderAndData(filename)	//this is the full Path+file

	Return(0)
End


//function that does the guts of reading the binary data file
//fname is the full path:name;vers required to open the file
//VAX record markers are skipped as needed
//VAX data as read in is in compressed I*2 format, and is decompressed
//immediately after being read in. The final root:RAW:data wave is the real
//neutron counts and can be directly operated on
//
// header information is put into three waves: integersRead, realsRead, and textRead
// logicals in the header are currently skipped, since they are no use in the 
// data reduction process.
//
// The output is the three R/T/I waves that are filled at least with minimal values
// and the detector data loaded into an array named "data"
//
// see documentation for the expected information in each element of the R/T/I waves
// and the minimum set of information. These waves can be increased in length so that
// more information can be accessed as needed (propagating changes...)
//
// called by multiple .ipfs (when the file name is known)
//
Function ReadHeaderAndData(fname)
	String fname
	//this function is for reading in RAW data only, so it will always put data in RAW folder
	String curPath = "root:Packages:NIST:RAW"
	SetDataFolder curPath		//use the full path, so it will always work
	Variable/G root:RAW:gIsLogScale = 0		//initial state is linear, keep this in RAW folder
	
	Variable refNum,integer,realval
	String sansfname="",textstr=""
	
	Make/O/N=23 $"root:Packages:NIST:RAW:IntegersRead"
	Make/O/N=52 $"root:Packages:NIST:RAW:RealsRead"
	Make/O/T/N=11 $"root:Packages:NIST:RAW:TextRead"
	
	Wave intw=$"root:Packages:NIST:RAW:IntegersRead"
	Wave realw=$"root:Packages:NIST:RAW:RealsRead"
	Wave/T textw=$"root:Packages:NIST:RAW:TextRead"
	
	Variable file
	String expr = "(.*)\t(.*)\r"
	String buf="", res=""			//buf : buffer, res : result
	
	readHeaderContents(fname, "FileName");
	
	
	textw[0] = readHeaderContents(fname, "FileName");
	textw[3] = readHeaderContents(fname, "FileName");
	textw[10] = readHeaderContents(fname, "User_Institute");
	textw[1] = readHeaderContents(fname, "Start_Time");
	textw[6] = readHeaderContents(fname, "Sample");

    intw[1] = str2num(readHeaderContents(fname, "Counting_Time(sec)"))
	intw[2] = str2num(readHeaderContents(fname, "Counting_Time(sec)"))

	realw[0] = str2num(readHeaderContents(fname, "Monitor_Counts"))
	realw[2] = str2num(readHeaderContents(fname, "Total_Counts"))
	realw[5] = str2num(readHeaderContents(fname, "Thickness(cm)"))
	realw[8] = str2num(readHeaderContents(fname, "Temp.(K)"))
	realw[9] = str2num(readHeaderContents(fname, "H-Field(Tesla)"))
	realw[26] = str2num(readHeaderContents(fname, "Wavelength"))
	realw[27] = str2num(readHeaderContents(fname, "Spread(FWHM)"))
	realw[18] = str2num(readHeaderContents(fname, "Sam_Det_Dis(m)"))
	realw[16] = str2num(readHeaderContents(fname, "Beam_Center(x)"))
	realw[17] = str2num(readHeaderContents(fname, "Beam_Center(y)"))
	realw[21] = str2num(readHeaderContents(fname, "Beam_Stop(mm)"))
	realw[3] = str2num(readHeaderContents(fname, "Atten_No"))
	realw[25] = str2num(readHeaderContents(fname, "Collimator(m)"))
	realw[23] = str2num(readHeaderContents(fname, "Beam_Aperture(A1)_Size(mm)"))
	realw[24] = str2num(readHeaderContents(fname, "Beam_Aperture(A2)_Size(mm)"))
	realw[4] = str2num(readHeaderContents(fname, "Transmission"))	
	
	realw[10] = 5
	realw[11]  = 10000
	realw[13] = 5
	realw[14]  = 10000
	
	//keep a string with the filename in the RAW folder
	String/G root:Packages:NIST:RAW:fileList = textw[0]
	
	SetDataFolder curPath		//use the full path, so it will always work
	
	NVAR size = root:myGlobals:gNPixelsX
	
	Make/O/N=(size*size) $"root:Packages:NIST:RAW:data"
	WAVE data=$"root:Packages:NIST:RAW:data"
	
	Open/R file as fname
	getDataFromFile(file, data)
	Redimension/N=(size,size) data
		
	//clean up - get rid of w = $"root:RAW:tempGBWave0"
	KillWaves/Z w

	Duplicate/O data,$"root:Packages:NIST:RAW:linear_data"
	
	//return the data folder to root
	SetDataFolder root:

	Close/A
	
	Return 0
End


Function ReadHeaderAndWork(type,fname)
	String type,fname
	
	String cur_folder = type
	String curPath = "root:Packages:NIST:"+cur_folder
	
	NVAR size = root:myGlobals:gNPixelsX
	
	Make/O/N=(size*size) $(curPath + ":data")
	WAVE data = $(curPath + ":data")
	
	Variable file
	Open/R file as fname
	getDataFromFile(file, data)
	Redimension/N=(size,size) data

	Close/A
	
	Return(0)
End



/////   ASC FORMAT READER  //////
/////   FOR WORKFILE MATH PANEL //////

//function to read in the ASC output of SANS reduction
// currently the file has 20 header lines, followed by a single column
// of 16384 values, Data is written by row, starting with Y=1 and X=(1->128)
//
//returns 0 if read was ok
//returns 1 if there was an error
//
// called by WorkFileUtils.ipf
//
Function ReadASCData(fname,destPath)
	String fname, destPath
	//this function is for reading in ASCII data so put data in user-specified folder
	SetDataFolder "root:"+destPath

	NVAR pixelsX = root:myGlobals:gNPixelsX
	NVAR pixelsY = root:myGlobals:gNPixelsY
	Variable refNum=0,ii,p1,p2,tot,num=pixelsX,numHdrLines=20
	String str=""
	//data is initially linear scale
	Variable/G :gIsLogScale=0
	Make/O/T/N=(numHdrLines) hdrLines
	Make/O/D/N=(pixelsX*pixelsY) data			//,linear_data
	
	//full filename and path is now passed in...
	//actually open the file
//	SetDataFolder destPath
	Open/R/Z refNum as fname		// /Z flag means I must handle open errors
	if(refnum==0)		//FNF error, get out
		DoAlert 0,"Could not find file: "+fname
		Close/A
		SetDataFolder root:
		return(1)
	endif
	if(V_flag!=0)
		DoAlert 0,"File open error: V_flag="+num2Str(V_Flag)
		Close/A
		SetDataFolder root:
		return(1)
	Endif
	// 
	for(ii=0;ii<numHdrLines;ii+=1)		//read (or skip) 18 header lines
		FReadLine refnum,str
		hdrLines[ii]=str
	endfor
	//	
	Close refnum
	
//	SetDataFolder destPath
	LoadWave/Q/G/D/N=temp fName
	Wave/Z temp0=temp0
	data=temp0
	Redimension/N=(pixelsX,pixelsY) data		//,linear_data
	
	//linear_data = data
	
	KillWaves/Z temp0 
	Close/A
	//return the data folder to root
	SetDataFolder root:
	
	Return(0)
End

// fills the "default" fake header so that the SANS Reduction machinery does not have to be altered
// pay attention to what is/not to be trusted due to "fake" information.
// uses what it can from the header lines from the ASC file (hdrLines wave)
//
// destFolder is of the form "myGlobals:WorkMath:AAA"
//
//
// called by WorkFileUtils.ipf
//
Function FillFakeHeader_ASC(destFolder)
	String destFolder
	Make/O/N=23 $("root:"+destFolder+":IntegersRead")
	Make/O/N=52 $("root:"+destFolder+":RealsRead")
	Make/O/T/N=11 $("root:"+destFolder+":TextRead")
	
	Wave intw=$("root:"+destFolder+":IntegersRead")
	Wave realw=$("root:"+destFolder+":RealsRead")
	Wave/T textw=$("root:"+destFolder+":TextRead")
	
	//Put in appropriate "fake" values
	//parse values as needed from headerLines
	Wave/T hdr=$("root:"+destFolder+":hdrLines")
	Variable monCt,lam,offset,sdd,trans,thick
	Variable xCtr,yCtr,a1,a2,a1a2Dist,dlam,bsDiam
	String detTyp=""
	String tempStr="",formatStr="",junkStr=""
	formatStr = "%g %g %g %g %g %g"
	tempStr=hdr[3]
	sscanf tempStr, formatStr, monCt,lam,offset,sdd,trans,thick
//	Print monCt,lam,offset,sdd,trans,thick,avStr,step
	formatStr = "%g %g %g %g %g %g %g %s"
	tempStr=hdr[5]
	sscanf tempStr,formatStr,xCtr,yCtr,a1,a2,a1a2Dist,dlam,bsDiam,detTyp
//	Print xCtr,yCtr,a1,a2,a1a2Dist,dlam,bsDiam,detTyp
	
	realw[16]=xCtr		//xCtr(pixels)
	realw[17]=yCtr	//yCtr (pixels)
	realw[18]=sdd		//SDD (m)
	realw[26]=lam		//wavelength (A)
	//
	// necessary values
	realw[10]=5			//detector calibration constants, needed for averaging
	realw[11]=10000
	realw[12]=0
	realw[13]=5
	realw[14]=10000
	realw[15]=0
	//
	// used in the resolution calculation, ONLY here to keep the routine from crashing
	realw[20]=65		//det size
	realw[27]=dlam	//delta lambda
	realw[21]=bsDiam	//BS size
	realw[23]=a1		//A1
	realw[24]=a2	//A2
	realw[25]=a1a2Dist	//A1A2 distance
	realw[4]=trans		//trans
	realw[3]=0		//atten
	realw[5]=thick		//thick
	//
	//
	realw[0]=monCt		//def mon cts

	// fake values to get valid deadtime and detector constants
	//
	textw[9]=detTyp+"  "		//6 characters 4+2 spaces
	textw[3]="[NGxSANS00]"	//11 chars, NGx will return default values for atten trans, deadtime... 
	
	//set the string values
	formatStr="FILE: %s CREATED: %s"
	sscanf hdr[0],formatStr,tempStr,junkStr

	String/G $("root:"+destFolder+":fileList") = tempStr
	textw[0] = tempStr		//filename
	textw[1] = junkStr		//run date-time
	
	tempStr = hdr[1]
	tempStr = tempStr[0,strlen(tempStr)-2]		//clean off the last LF

	textW[6] = tempStr	//sample label
	
	return(0)
End



Function getXYBoxFromFile(filename,x1,x2,y1,y2)
	String filename
	Variable &x1,&x2,&y1,&y2
	
	Variable refnum
	String tmpFile = FindValidFilename(filename)
	
	x1 = str2num(readHeaderContents(filename, "BoxX1"))
	x2 = str2num(readHeaderContents(filename, "BoxX2"))
	y1 = str2num(readHeaderContents(filename, "BoxY1"))
	y2 = str2num(readHeaderContents(filename, "BoxY2"))
	
	return(0)
End

Function WriteXYBoxToHeader(filename,x1,x2,y1,y2)
	String filename
	Variable x1,x2,y1,y2
	
	writeHeaderContents(filename, "BoxX1", num2str(x1))
	writeHeaderContents(filename, "BoxX2", num2str(x2))
	writeHeaderContents(filename, "BoxY1", num2str(y1))
	writeHeaderContents(filename, "BoxY2", num2str(y2))
	
	return(0)
End


// file suffix (NCNR data file name specific)
Function/S getSuffix(fname)
	String fname
	return fname
End

// associated file suffix (for transmission)
Function/S getAssociatedFileSuffix(fname)
	String fname
	return fname
End

Function/S getSampleLabel(filename)
	String filename	
	return(readHeaderContents(filename, "Sample"))
End

Function/S getFileCreationDate(fname)
	String fname
	return "Not supported"
End

Function/S getFileName(fname)
	String fname	
	return(readHeaderContents(fname, "FileName"))
End

Function getMonitorCount(fname)
	String fname	
	return(str2num(readHeaderContents(fname, "Monitor_Counts")))
end

Function getDetCount(fname)
	String fname	
	return(str2num(readHeaderContents(fname, "Total_Counts")))
end

Function getAttenNumber(fname)
	String fname	
	return(str2num(readHeaderContents(fname, "Atten_No")))
end

Function getSampleTrans(fname)
	String fname	
	return(str2num(readHeaderContents(fname, "Transmission")))
end

Function getBoxCounts(fname)
	String fname	
	return(str2num(readHeaderContents(fname, "BoxCountsToHeader")))
end

Function getSampleTransWholeDetector(fname)
	String fname
	return(str2num(readHeaderContents(fname, "WholeTrans")))
end

Function getSampleThickness(fname)
	String fname
	return(str2num(readHeaderContents(fname, "Thickness(cm)")))
end

Function getSampleRotationAngle(fname)
	String fname
	//TODO:Not implemented!
	return 0;
end

Function getTemperature(fname)
	String fname	
	return(str2num(readHeaderContents(fname, "Temp.(K)")))
end

Function getFieldStrength(fname)
	String fname
	return(str2num(readHeaderContents(fname, "H-Field(Tesla)")))
end

Function getSDD(fname)
	String fname	
	return(str2num(readHeaderContents(fname, "Sam_Det_Dis(m)")))
end

Function getDetectorOffset(fname)
	String fname	
	return(str2num(readHeaderContents(fname, "Det_Offset")))
end

Function getBSDiameter(fname)
	String fname	
	return(str2num(readHeaderContents(fname, "Beam_Stop(mm)")))
end

Function getSourceApertureDiam(fname)
	String fname	
	return(str2num(readHeaderContents(fname, "Beam_Aperture(A1)_Size(mm)")))
end

Function getSampleApertureDiam(fname)
	String fname	
	return(str2num(readHeaderContents(fname, "Beam_Aperture(A2)_Size(mm)")))
end

Function getSourceToSampleDist(fname)
	String fname	
	return(str2num(readHeaderContents(fname, "Collimator(m)")))
end

Function getWavelength(fname)
	String fname	
	return(str2num(readHeaderContents(fname, "Wavelength")))
end

Function getWavelengthSpread(fname)
	String fname	
	return(str2num(readHeaderContents(fname, "Spread(FWHM)")))
end

Function getTransDetectorCounts(fname)
	String fname	
	return(str2num(readHeaderContents(fname, "Trans_Detec_Counts")))
end

Function getBeamXPos(fname)
	String fname	
	return(str2num(readHeaderContents(fname, "Beam_Center(x)")))
end

Function getBeamYPos(fname)
	String fname	
	return(str2num(readHeaderContents(fname, "Beam_Center(y)")))
end

Function isTransmissionFile(fname)
	String fname
	return stringmatch(readHeaderContents(fname, "Trans/Run"), "Trans")
end

Function getIntegerFromHeader(fname,start)
	String fname				//full path:name
	Variable start		//starting byte
	
	Variable refnum,val
	Open/R refNum as fname
	FSetPos refNum,start
	FBinRead/B=3/F=3 refnum,val
	Close/A
	
	return(val)
End

Function getCountTime(fname)
	String fname
	return(str2num(readHeaderContents(fname, "Counting_Time(sec)")))
end


//reads the wavelength from a reduced data file (not very reliable)
// - does not work with NSORTed files
// - only used in FIT/RPA (which itself is almost NEVER used...)
//
// DOES NOT NEED TO BE CHANGED IF USING NCNR DATA WRITER
Function GetLambdaFromReducedData(tempName)
	String tempName
	
	String junkString=""
	Variable lambdaFromFile, fileVar, junkVal
	lambdaFromFile = 6.0

	Open/R/P=catPathName fileVar as tempName
	FReadLine fileVar, junkString
	FReadLine fileVar, junkString
	FReadLine fileVar, junkString
	if(strsearch(LowerStr(junkString),"lambda",0) != -1)
		FReadLine/N=11 fileVar, junkString
		FReadLine/N=10 fileVar, junkString
		sscanf  junkString, "%f",junkVal

		lambdaFromFile = junkVal
	endif
	Close fileVar
	
	return(lambdaFromFile)
End


Function WriteAssocFileSuffixToHeader(fname,suffix)
	String fname,suffix
	return(0)
end

Function WriteTransmissionToHeader(filename,trans)
	String filename
	Variable trans	
	writeHeaderContents(filename, "Transmission", num2str(trans))
	return(0)
End

Function WriteWholeTransToHeader(filename,trans)
	String filename
	Variable trans	
	writeHeaderContents(filename, "WholeTrans", num2str(trans))
	return(0)
End

Function WriteBoxCountsToHeader(filename,counts)
	String filename
	Variable counts
	writeHeaderContents(filename, "BoxCountsToHeader", num2str(counts))
	return(0)
End

Function WriteThicknessToHeader(filename,num)
	String filename
	Variable num
	writeHeaderContents(filename, "Thickness(cm)", num2str(num))
	return(0)
End

Function WriteBeamCenterXToHeader(filename,num)
	String filename
	Variable num
	writeHeaderContents(filename, "Beam_Center(x)", num2str(num))
	return(0)
End

Function WriteBeamCenterYToHeader(filename,num)
	String filename
	Variable num	
	writeHeaderContents(filename, "Beam_Center(y)", num2str(num))	
	return(0)
End

Function WriteAttenNumberToHeader(filename,num)
	String filename
	Variable num	
	writeHeaderContents(filename, "Atten_No", num2str(num))
	return(0)
End

Function WriteMonitorCountToHeader(filename,num)
	String filename
	Variable num	
	writeHeaderContents(filename, "Monitor_Counts", num2str(num))
	return(0)
End

Function WriteDetectorCountToHeader(filename,num)
	String filename
	Variable num	
	writeHeaderContents(filename, "Total_Counts", num2str(num))
	return(0)
End

Function WriteTransDetCountToHeader(filename,num)
	String filename
	Variable num	
	writeHeaderContents(filename, "Trans_Detec_Counts", num2str(num))
	return(0)
End

Function WriteWavelengthToHeader(filename,num)
	String filename
	Variable num	
	writeHeaderContents(filename, "Wavelength", num2str(num))
	return(0)
End

Function WriteWavelengthDistrToHeader(filename,num)
	String filename
	Variable num	
	writeHeaderContents(filename, "Spread(FWHM)",num2str(num))
	return(0)
End

Function WriteTemperatureToHeader(filename,num)
	String filename
	Variable num	
	writeHeaderContents(filename, "Temp.(K)", num2str(num))
	return(0)
End

Function WriteMagnFieldToHeader(filename,num)
	String filename
	Variable num	
	writeHeaderContents(filename, "H-Field(Tesla)", num2str(num))
	return(0)
End

Function WriteSourceApDiamToHeader(filename,num)
	String filename
	Variable num	
	writeHeaderContents(filename, "Beam_Aperture(A1)_Size(mm)", num2str(num))
	return(0)
End

Function WriteSampleApDiamToHeader(filename,num)
	String filename
	Variable num	
	writeHeaderContents(filename, "Beam_Aperture(A2)_Size(mm)", num2str(num))
	return(0)
End

Function WriteSrcToSamDistToHeader(filename,num)
	String filename
	Variable num	
	writeHeaderContents(filename, "Collimator(m)", num2str(num))
	return(0)
End

Function WriteDetectorOffsetToHeader(filename,num)
	String filename
	Variable num	
	writeHeaderContents(filename, "Det_Offset", num2str(num))
	return(0)
End

Function WriteBeamStopDiamToHeader(filename,num)
	String filename
	Variable num	
	writeHeaderContents(filename, "Beam_Stop(mm)", num2str(num))
	return(0)
End

Function WriteBSXPosToHeader(fname,xpos)
	String fname
	Variable xpos
	//TODO: do nothing
	return(0)
End

Function WriteSDDToHeader(filename,num)
	String filename
	Variable num	
	writeHeaderContents(filename, "Sam_Det_Dis(m)", num2str(num))
	return(0)
End

Function WriteSamLabelToHeader(filename,str)
	String filename,str	
	if(strlen(str) > 60)
		str = str[0,59]
	endif	
	writeHeaderContents(filename, "Sample", str)
	return(0)
End

Function WriteCountTimeToHeader(filename,num)
	String filename
	Variable num
	writeHeaderContents(filename, "Counting_Time(sec)", num2str(num))
	return(0)
End


//	getDataFromFile
//	read 2D matrix text data, and return to n*n 1D wave
//	usage : getDataFromText("10121", wave)

//// params
//	filename : file name to read data
// 	out : wave to get data
function getDataFromFile(file, out)
	Variable file
	wave out
	
	Variable i, j
	String buf="", buf2="", tmp=""
	NVAR dim = root:myGlobals:gNPixelsX
	
	do
		FReadLine file, buf
		if(cmpstr(buf, "") == 0)
			break
		endif
	while(cmpstr(buf, " \r") != 0)
	
	String expr = "([0-9.]+)[ 	](.*)"
	for(i = 0; i < dim; i=i+1)
		FReadLine file, buf
		for(j = 0; j < dim; j=j+1)
			if(j == dim -1)
				out[j+i*dim] = str2num(buf)
				break
			endif
			SplitString/E=(expr) buf, tmp, buf
			out[j+i*dim] = str2num(tmp)
		endfor
	endfor
	
	Close/A
end

//	readHeaderContents
//	read content
//	usage : writeHaderContents("10121", "Transmission")

//// params
//	filename : file name to write contents
// 	requestedContent : content name
//						ex) Transmission

//// return value
//	string format. if you want to get a integer(or floating) value, use str2num built-in funtion
function/S readHeaderContents(filename, requestedContent)
	string filename, requestedContent;
	
	Variable file, i
	String buf, tmp
	String expr = "(.*)\t(.*)\r"
	
	Open/R file as filename
	
	do
		FReadLine file, buf	
		if(cmpstr(buf, "") == 0)
			break
		endif
		SplitString/E=(expr) buf, tmp, buf
	while(cmpstr(tmp, requestedContent) != 0)

	Close/A
	
	return(buf)
end

//	writeHeaderContents
//	write(or overwrite) content
//	usage : writeHaderContents("10121", "Transmission", "0.749")

//// params
//	filename : file name to write contents
// 	requestedContent : content name
//						ex) Transmission
//	content : content
//						ex) 0.74
function writeHeaderContents(filename, requestedContent, content)
	string filename, requestedContent, content
	
	Variable file, i
	String buf, tmp
	String expr = "(.*)\t(.*)\r"
	
	variable tmpFile, V_filePos
	
	CopyFile filename as filename+".tmp"
	
	Open/R file as filename
	
	do
		FStatus file
		FReadLine file, buf	
		if(cmpstr(buf, "") == 0)
			break
		endif
		SplitString/E=(expr) buf, tmp, buf
	while(cmpstr(tmp, requestedContent) != 0)
	
	Close/A
	
	Open/A file as filename
	Open/R tmpFile as filename+".tmp"
	
	FSetPos file, V_filePos
	FSetPos tmpFile, V_filePos
	FReadLine tmpFile, buf
	
	
	fprintf file, requestedContent+"\t%s\r\n", content
	
	FReadLine /N=1000 tmpFile, buf	
	do
		if (strlen(buf) == 1000)
			fprintf file, buf
		else
			fprintf file, "%s\n", buf
		endif
		FReadLine /N=1000 tmpFile, buf	
	while(cmpstr(buf, "") != 0)
	
	Close/A
	
	DeleteFile filename+".tmp"
	
	return(0)
end

Function ReadWork_DIV()
	String fname = PromptForPath("Select detector sensitivity file")
	
	ReadHeaderAndWork("DIV",fname)
End

////// OCT 2009, facility specific bits from ProDiv()
//"type" is the data folder that has the corrected, patched, and normalized DIV data array
//
// the header of this file is rather unimportant. Filling in a title at least would be helpful/
//
Function Write_DIV_File(type)
	String type
	
	// Your file writing function here. Don't try to duplicate the VAX binary format...
	Variable i, j, file;
	NVAR dim = root:myGlobals:gNPixelsX;
	WAVE data=$("root:Packages:NIST:"+type+":data");
	String fname=""
	fname = DoSaveFileDialog("Save data as")

	Open file as fname
	
	fprintf file, " \r\n"
	for(i=0;i<dim;i+=1)
		for(j=0;j<dim;j+=1)
			fprintf file, "%f ", data[i][j]
		endfor
		fprintf file, "\r\n"
	endfor
	
	Close file
	
	return(0)
End

////// OCT 2009, facility specific bits from MonteCarlo functions()
//"type" is the data folder that has the data array that is to be (re)written as a full
// data file, as if it was a raw data file
//
// not really necessary
//
Function Write_RawData_File(type,fullpath,dialog)
	String type,fullpath
	Variable dialog		//=1 will present dialog for name
	
	// Your file writing function here. Don't try to duplicate the VAX binary format...
	Print "Write_RawData_File stub"
	
	return(0)
End
