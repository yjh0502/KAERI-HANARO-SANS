#pragma rtGlobals=1		// Use modern global access method.
#pragma version=4.00
#pragma IgorVersion=6.1

// This is to be used with the Analysis packages ONLY
// there are a number of utility procedures here for loading
// data and generating valid lists of data files that are
// directly copied from the Reduction package
// -- There WILL be name conflicts if you mix the two...
//
// 16 DEC 05 SRK
// prepended function names with A_ to tag them for the 
// "A"nalysis parckage, though nearly all are duplicate procedures
// so there will be no overlap with the reduction package
//
//
// these extra procedures are used by:
// Linearized fits (duplicated in Reduction - will need to handle gently)
// Invariant (no overlap with reduction)
//
// SRK MAR 2005

// create a KW=string; of model=coef correspondence as the models are plotted, rather than
// some other hard-wired solution
Function AddModelToStrings(funcStr,coefStr,paramStr,suffix)
	String funcStr,coefStr,paramStr,suffix
	
	if(exists("root:Packages:NIST:paramKWStr")==0)
//		String/G root:Packages:NIST:coefKWStr=""
		String/G root:Packages:NIST:paramKWStr=""
//		String/G root:Packages:NIST:suffixKWStr=""
	endif
	SVAR coefKWStr = root:Packages:NIST:coefKWStr
	SVAR paramKWStr = root:Packages:NIST:paramKWStr
	SVAR suffixKWStr = root:Packages:NIST:suffixKWStr
	coefKWStr += funcStr+"="+coefStr+";"
	paramKWStr += funcStr+"="+paramStr+";"
	suffixKWStr += funcStr+"="+suffix+";"
end

// loads a 1-d (ascii) datafile and plots the data
// will overwrite existing data if user is OK with this
// - multiple datasets can be automatically plotted on the same graph
//
//substantially easier to write this as a Proc rather than a function...

//
Proc A_LoadOneDData()
	A_LoadOneDDataWithName("",1)		//will prompt for file and plot data
End

// load the data specified by fileStr (a full path:name)
// and plots if doPlot==1
// if fileStr is null, a dialog is presented to select the file
//
// 3 cases (if)
// - 3 columns = QIS, no resolution
// - 6 columns = QSIG, SANS w/resolution
// - 5 columns = old-style desmeared USANS data (from VAX)
//
// This loader replaces the A_LoadOneDData() which was almost completely duplicated code
//
//new version, 19JUN07 that loads each data set into a separate data folder
// the data folder is given the "base name" of the data file as it's loaded
//

Proc A_LoadOneDDataWithName(fileStr,doPlot)
	String fileStr
	Variable doPlot
	
	A_LoadOneDDataToName(fileStr,"",doPlot,0)

End


///Function that takes output name as well as input
Proc A_LoadOneDDataToName(fileStr,outStr,doPlot,forceOverwrite)
	String fileStr, outstr
	Variable doPlot,forceOverwrite
	
	Variable rr,gg,bb,refnum,dQv
	String w0,w1,w2,n0,n1,n2
	String w3,w4,w5,n3,n4,n5			//3 extra waves to load
	SetDataFolder root:		//build sub-folders for each data set under root

// I can't see that we need to find dQv here.	
//	if (exists("root:Packages:NIST:USANS:Globals:MainPanel:gDQv"))
//		//Running from USANS reduction
//		Variable dQv = root:Packages:NIST:USANS:Globals:MainPanel:gDQv
//	endif
//	if(exists("root:Packages:NIST:USANS_dQv"))
//		//Running from SANS Analysis
//		Variable dQv = root:Packages:NIST:USANS_dQv
//	else
//		//running from somewhere else, probably SANS Reduction, which uses common loaders
//		Variable/G root:Packages:NIST:USANS_dQv = 0.117
//	endif
	String angst = StrVarOrDefault("root:Packages:NIST:gAngstStr", "A" )

	// if no fileStr passed in, display dialog now
	if (cmpStr(fileStr,"") == 0)
		fileStr = DoOpenFileDialog("Select a data file to load")
		if (cmpstr(fileStr,"") == 0)
			String/G root:Packages:NIST:gLastFileName = ""
			return		//get out if no file selected
		endif
	endif

	if (isXML(fileStr) == 1)
		LoadNISTXMLData(fileStr,outstr,doPlot,forceOverwrite)
	else		
		//Load the waves, using default waveX names
		//if no path or file is specified for LoadWave, the default Mac open dialog will appear
		LoadWave/G/D/A/Q fileStr
		String fileNamePath = S_Path+S_fileName
//		String basestr = ParseFilePath(3,ParseFilePath(5,fileNamePath,":",0,0),":",0,0)

		String basestr
		if (!cmpstr(outstr, ""))		//Outstr = "", cmpstr returns 0
//			enforce a short enough name here to keep Igor objects < 31 chars
			baseStr = ShortFileNameString(CleanupName(S_fileName,0))
			baseStr = CleanupName(baseStr,0)		//in case the user added odd characters
			//baseStr = CleanupName(S_fileName,0)
		else
			baseStr = outstr			//for output, hopefully correct length as passed in
		endif
	
//		print "basestr :"+basestr
		String fileName =  ParseFilePath(0,ParseFilePath(5,filestr,":",0,0),":",1,0)
//		print "filename :"+filename
		Variable numCols = V_flag
		
		//changes JIL to allow 2-column data to be read in, "faking" a 3rd column of errors
		if(numCols==2) //no errors
			n1 = StringFromList(1, S_waveNames ,";" )
			Duplicate/O $("root:"+n1), errorTmp
			errorTmp = 0.01*(errorTmp)+ 0.03*sqrt(errorTmp)
			S_waveNames+="errorTmp;"
			numCols=3
		endif
		
		if(numCols==3)		//simple 3-column data with no resolution information
			
			// put the names of the three loaded waves into local names
			n0 = StringFromList(0, S_waveNames ,";" )
			n1 = StringFromList(1, S_waveNames ,";" )
			n2 = StringFromList(2, S_waveNames ,";" )
			
			//remove the semicolon AND period from files from the VAX
			w0 = CleanupName((basestr + "_q"),0)
			w1 = CleanupName((basestr + "_i"),0)
			w2 = CleanupName((basestr + "_s"),0)
			
			//String baseStr=w1[0,strlen(w1)-3]
			if(DataFolderExists("root:"+baseStr))
				if (!forceOverwrite)
					DoAlert 1,"The file "+S_filename+" has already been loaded. Do you want to load the new data file, overwriting the data in memory?"
					if(V_flag==2)	//user selected No, don't load the data
						SetDataFolder root:
						KillWaves $n0,$n1,$n2		// kill the default waveX that were loaded
						if(DataFolderExists("root:Packages:NIST"))
							String/G root:Packages:NIST:gLastFileName = filename
						endif
						return	//quits the macro
					endif
				endif
				SetDataFolder $("root:"+baseStr)
			else
				NewDataFolder/S $("root:"+baseStr)
			endif

			
			////overwrite the existing data, if it exists
			Duplicate/O $("root:"+n0), $w0
			Duplicate/O $("root:"+n1), $w1
			Duplicate/O $("root:"+n2), $w2
	
			// no resolution matrix to make
	
			SetScale d,0,0,"1/A",$w0
			SetScale d,0,0,"1/cm",$w1
			
		endif		//3-col data
		
		if(numCols == 6)		//6-column SANS or USANS data that has resolution information
			
			// put the names of the (default named) loaded waves into local names
			n0 = StringFromList(0, S_waveNames ,";" )
			n1 = StringFromList(1, S_waveNames ,";" )
			n2 = StringFromList(2, S_waveNames ,";" )
			n3 = StringFromList(3, S_waveNames ,";" )
			n4 = StringFromList(4, S_waveNames ,";" )
			n5 = StringFromList(5, S_waveNames ,";" )
			
			//remove the semicolon AND period from files from the VAX
			w0 = CleanupName((basestr + "_q"),0)
			w1 = CleanupName((basestr + "_i"),0)
			w2 = CleanupName((basestr + "_s"),0)
			w3 = CleanupName((basestr + "sq"),0)
			w4 = CleanupName((basestr + "qb"),0)
			w5 = CleanupName((basestr + "fs"),0)
			
			//String baseStr=w1[0,strlen(w1)-3]
			if(DataFolderExists("root:"+baseStr))
				if(!forceOverwrite)
					DoAlert 1,"The file "+S_filename+" has already been loaded. Do you want to load the new data file, overwriting the data in memory?"
					if(V_flag==2)	//user selected No, don't load the data
						SetDataFolder root:
						KillWaves $n0,$n1,$n2,$n3,$n4,$n5		// kill the default waveX that were loaded
						if(DataFolderExists("root:Packages:NIST"))
							String/G root:Packages:NIST:gLastFileName = filename
						endif
						return		//quits the macro
					endif
				endif
				SetDataFolder $("root:"+baseStr)
			else
				NewDataFolder/S $("root:"+baseStr)
			endif



	
	////overwrite the existing data, if it exists
			Duplicate/O $("root:"+n0), $w0
			Duplicate/O $("root:"+n1), $w1
			Duplicate/O $("root:"+n2), $w2
			Duplicate/O $("root:"+n3), $w3
			Duplicate/O $("root:"+n4), $w4
			Duplicate/O $("root:"+n5), $w5
	
			// need to switch based on SANS/USANS
			if (isSANSResolution($w3[0]))		//checks to see if the first point of the wave is <0]
				// make a resolution matrix for SANS data
				Variable np=numpnts($w0)
				Make/D/O/N=(np,4) $(baseStr+"_res")
				
				$(baseStr+"_res")[][0] = $w3[p]		//sigQ
				$(baseStr+"_res")[][1] = $w4[p]		//qBar
				$(baseStr+"_res")[][2] = $w5[p]		//fShad
				$(baseStr+"_res")[][3] = $w0[p]		//Qvalues
			else
				//the data is USANS data
				// marix calculation here, but for now, just copy the waves
				//$(baseStr+"_res")[][0] = $w3[p]		//sigQ
				//$(baseStr+"_res")[][1] = $w4[p]		//qBar
				//$(baseStr+"_res")[][2] = $w5[p]		//fShad
				//$(baseStr+"_res")[][3] = $w0[p]		//Qvalues
				dQv = -$w3[0]
				
				USANS_CalcWeights(baseStr,dQv)
				
			endif
			Killwaves/Z $w3,$w4,$w5			//get rid of the resolution waves that are in the matrix
	
			SetScale d,0,0,"1/A",$w0
			SetScale d,0,0,"1/cm",$w1
		
		endif	//6-col data
	
		// Load ORNL data from Heller program
		if(numCols == 4)		//4-column SANS or USANS data that has resolution information
			
			// put the names of the (default named) loaded waves into local names
			n0 = StringFromList(0, S_waveNames ,";" )
			n1 = StringFromList(1, S_waveNames ,";" )
			n2 = StringFromList(2, S_waveNames ,";" )
			n3 = StringFromList(3, S_waveNames ,";" )
			
			//remove the semicolon AND period from files from the VAX
			w0 = CleanupName((basestr + "_q"),0)
			w1 = CleanupName((basestr + "_i"),0)
			w2 = CleanupName((basestr + "_s"),0)
			w3 = CleanupName((basestr + "sq"),0)
			w4 = CleanupName((basestr + "qb"),0)
			w5 = CleanupName((basestr + "fs"),0)
	
			
			//String baseStr=w1[0,strlen(w1)-3]
			if(DataFolderExists("root:"+baseStr))
				if(!forceOverwrite)
					DoAlert 1,"The file "+S_filename+" has already been loaded. Do you want to load the new data file, overwriting the data in memory?"
					if(V_flag==2)	//user selected No, don't load the data
						SetDataFolder root:
						KillWaves $n0,$n1,$n2,$n3		// kill the default waveX that were loaded
						if(DataFolderExists("root:Packages:NIST"))
							String/G root:Packages:NIST:gLastFileName = filename
						endif
						return		//quits the macro
					endif
				endif
				SetDataFolder $("root:"+baseStr)
			else
				NewDataFolder/S $("root:"+baseStr)
			endif
	


	
	////overwrite the existing data, if it exists
			Duplicate/O $("root:"+n0), $w0
			Duplicate/O $("root:"+n1), $w1
			Duplicate/O $("root:"+n2), $w2
			Duplicate/O $("root:"+n3), $w3
			Duplicate/O $("root:"+n0), $w4 // Set qb wave to nominal measured Q values
			Duplicate/O $("root:"+n0), $w5 // Make wave of appropriate length
			$w4 = $w0
			$w5 = 1						  //  Set all shadowfactor to 1
	
			// need to switch based on SANS/USANS
			if (isSANSResolution($w3[0]))		//checks to see if the first point of the wave is <0]
				// make a resolution matrix for SANS data
				Variable np=numpnts($w0)
				Make/D/O/N=(np,4) $(baseStr+"_res")
				
				$(baseStr+"_res")[][0] = $w3[p]		//sigQ
				$(baseStr+"_res")[][1] = $w4[p]		//qBar
				$(baseStr+"_res")[][2] = $w5[p]		//fShad
				$(baseStr+"_res")[][3] = $w0[p]		//Qvalues
			else
				//the data is USANS data
				// marix calculation here, but for now, just copy the waves
				//$(baseStr+"_res")[][0] = $w3[p]		//sigQ
				//$(baseStr+"_res")[][1] = $w4[p]		//qBar
				//$(baseStr+"_res")[][2] = $w5[p]		//fShad
				//$(baseStr+"_res")[][3] = $w0[p]		//Qvalues
				dQv = -$w3[0]
				
				USANS_CalcWeights(baseStr,dQv)
				
			endif
			Killwaves/Z $w3,$w4,$w5			//get rid of the resolution waves that are in the matrix
	
			SetScale d,0,0,"1/A",$w0
			SetScale d,0,0,"1/cm",$w1
		
		endif	//4-col data
	
	
		if(numCols==5)		//this is the "old-style" VAX desmeared data format
			
			// put the names of the three loaded waves into local names
			n0 = StringFromList(0, S_waveNames ,";" )
			n1 = StringFromList(1, S_waveNames ,";" )
			n2 = StringFromList(2, S_waveNames ,";" )
			n3 = StringFromList(3, S_waveNames ,";" )
			n4 = StringFromList(4, S_waveNames ,";" )
			
			
			//remove the semicolon AND period from files from the VAX
			w0 = CleanupName((basestr+"_q"),0)
			w1 = CleanupName((basestr+"_i"),0)
			w2 = CleanupName((basestr+"_s"),0)
			w3 = CleanupName((basestr+"_ism"),0)
			w4 = CleanupName((basestr+"_fit_ism"),0)
			
			//String baseStr=w1[0,strlen(w1)-3]
			if(DataFolderExists("root:"+baseStr))
				if(!forceOverwrite)
					DoAlert 1,"The file "+S_filename+" has already been loaded. Do you want to load the new data file, overwriting the data in memory?"
					if(V_flag==2)	//user selected No, don't load the data
						KillWaves $n0,$n1,$n2,$n3,$n4,$n5		// kill the default waveX that were loaded
						if(DataFolderExists("root:Packages:NIST"))
							String/G root:Packages:NIST:gLastFileName = filename
						endif		//set the last file loaded to the one NOT loaded
						return		//quits the macro
					endif
				endif
				SetDataFolder $("root:"+baseStr)
			else
				NewDataFolder/S $("root:"+baseStr)
			endif
			
			////overwrite the existing data, if it exists	
			Duplicate/O $("root:"+n0), $w0
			Duplicate/O $("root:"+n1), $w1
			Duplicate/O $("root:"+n2), $w2
			Duplicate/O $("root:"+n3), $w3
			Duplicate/O $("root:"+n4), $w4
			
			// no resolution matrix
		endif		//5-col data

		//////
		if(DataFolderExists("root:Packages:NIST"))
			String/G root:Packages:NIST:gLastFileName = filename
		endif
	
		
		//plot if desired
		if(doPlot)
			Print GetDataFolder(1)
			
			// assign colors randomly
			rr = abs(trunc(enoise(65535)))
			gg = abs(trunc(enoise(65535)))
			bb = abs(trunc(enoise(65535)))
			
			// if target window is a graph, and user wants to append, do so
		   DoWindow/B Plot_Manager
			if(WinType("") == 1)
				DoAlert 1,"Do you want to append this data to the current graph?"
				
				
				if(V_Flag == 1)
					AppendToGraph $w1 vs $w0
					ModifyGraph mode($w1)=3,marker($w1)=19,msize($w1)=2,rgb($w1) =(rr,gg,bb),tickUnit=1
					ErrorBars/T=0 $w1 Y,wave=($w2,$w2)
					ModifyGraph tickUnit(left)=1
				else
				//new graph
					SetDataFolder $("root:"+baseStr)		//sometimes I end up back in root: here, and I can't figure out why!
					Display $w1 vs $w0
					ModifyGraph log=1,mode($w1)=3,marker($w1)=19,msize($w1)=2,rgb($w1)=(rr,gg,bb),tickUnit=1
					ModifyGraph grid=1,mirror=2,standoff=0
					ErrorBars/T=0 $w1 Y,wave=($w2,$w2)
					ModifyGraph tickUnit(left)=1
					Label left "I(q)"
					Label bottom "q ("+angst+"\\S-1\\M)"
					Legend
				endif
			else
			// graph window was not target, make new one
				Display $w1 vs $w0
				ModifyGraph log=1,mode($w1)=3,marker($w1)=19,msize($w1)=2,rgb($w1)=(rr,gg,bb),tickUnit=1
				ModifyGraph grid=1,mirror=2,standoff=0
				ErrorBars/T=0 $w1 Y,wave=($w2,$w2)
				ModifyGraph tickUnit(left)=1
				Label left "I(q)"
				Label bottom "q ("+angst+"\\S-1\\M)"
				Legend
			endif
		endif
			
		//go back to the root folder and clean up before leaving
		SetDataFolder root:
		KillWaves/Z $n0,$n1,$n2,$n3,$n4,$n5
		
	endif
End


//procedure for loading NSE data in the format (4-columns)
// qvals - time - I(q,t) - dI(q,t)
//
//
// this does NOT load the data into separate folders...
//
Proc A_LoadNSEData()
	A_LoadNSEDataWithName("",1)
End

Proc A_LoadNSEDataWithName(fileStr,doPlot)

	//Load the waves, using default waveX names
	//if no path or file is specified for LoadWave, the default Mac open dialog will appear
	LoadWave/G/D/A  fileStr
	String filename = S_fileName
	
	String w0,w1,w2,n0,n1,n2,wt,w3,n3
	Variable rr,gg,bb
	
	// put the names of the three loaded waves into local names
	n0 = StringFromList(0, S_waveNames ,";" )
	n1 = StringFromList(1, S_waveNames ,";" )
	n2 = StringFromList(2, S_waveNames ,";" )
	n3 = StringFromList(3, S_waveNames ,";" )
	
	
	//remove the semicolon AND period from files from the VAX
	w0 = CleanupName(("qvals_"+S_fileName),0)
	w1 = CleanupName(("time_"+S_fileName),0)
	w2 = CleanupName(("iqt_"+S_fileName),0)
	w3 = CleanupName(("iqterr_"+S_fileName),0)
	
	if(exists(w0) !=0)
		DoAlert 0,"This file has already been loaded. Use Append to Graph..."
		KillWaves $n0,$n1,$n2		// kill the default waveX that were loaded
		return
	endif
	
	// Rename to give nice names
	Rename $n0, $w0
	Rename $n1, $w1
	Rename $n2, $w2
	Rename $n3, $w3
		
	if(doPlot)
		// assign colors randomly
		rr = abs(trunc(enoise(65535)))
		gg = abs(trunc(enoise(65535)))
		bb = abs(trunc(enoise(65535)))
		
		// if target window is a graph, and user wants to append, do so
		if(WinType("") == 1)
			DoAlert 1,"Do you want to append this data to the current graph?"
			if(V_Flag == 1)
				AppendToGraph $w2 vs $w1
				ModifyGraph mode($w2)=3,marker($w2)=29,msize($w2)=2,rgb($w2) =(rr,gg,bb),grid=1,mirror=2,tickUnit=1
				ErrorBars/T=0 $w2 Y,wave=($w3,$w3)
			else
			//new graph
				Display $w2 vs $w1
				ModifyGraph standoff=0,mode($w2)=3,marker($w2)=29,msize($w2)=2,rgb($w2)=(rr,gg,bb),grid=1,mirror=2,tickUnit=1
				ErrorBars/T=0 $w2 Y,wave=($w3,$w3)
				Legend
			endif
		else
		// graph window was not target, make new one
			Display $w2 vs $w1
			ModifyGraph standoff=0,mode($w2)=3,marker($w2)=29,msize($w2)=2,rgb($w2)=(rr,gg,bb),grid=1,mirror=2,tickUnit=1
			ErrorBars/T=0 $w2 Y,wave=($w3,$w3)
			Legend
		endif
	endif //doPlot		

End

//procedure for loading desmeared USANS data in the format (5-columns)
// qvals - I(q) - sig I - Ism(q) - fitted Ism(q)
//no weighting wave is created (not needed in IGOR 4)
//
// not really ever used...
//
Proc A_LoadUSANSData()

	//Load the waves, using default waveX names
	//if no path or file is specified for LoadWave, the default Mac open dialog will appear
	LoadWave/G/D/A
   String filename = S_fileName
	
	String w0,w1,w2,n0,n1,n2,w3,n3,w4,n4
	Variable rr,gg,bb
	
	// put the names of the three loaded waves into local names
	n0 = StringFromList(0, S_waveNames ,";" )
	n1 = StringFromList(1, S_waveNames ,";" )
	n2 = StringFromList(2, S_waveNames ,";" )
	n3 = StringFromList(3, S_waveNames ,";" )
	n4 = StringFromList(4, S_waveNames ,";" )
	
	
	//remove the semicolon AND period from files from the VAX
	w0 = CleanupName((S_fileName+"_q"),0)
	w1 = CleanupName((S_fileName+"_i"),0)
	w2 = CleanupName((S_fileName+"_s"),0)
	w3 = CleanupName((S_fileName+"_ism"),0)
	w4 = CleanupName((S_fileName+"_fit_ism"),0)
	
	if(exists(w0) !=0)		//the wave already exists
		DoAlert 1,"This file "+S_filename+" has already been loaded. Do you want to load the new data file, overwriting the data in memory?"
		if(V_flag==2)	//user selected No
			KillWaves $n0,$n1,$n2,$n3,$n4		// kill the default waveX that were loaded
			if(DataFolderExists("root:Packages:NIST"))
				String/G root:Packages:NIST:gLastFileName = filename
			endif		//set the last file loaded to the one NOT loaded
			return		//quits the macro
		endif
	endif
	
	////overwrite the existing data, if it exists
	Duplicate/O $n0, $w0
	Duplicate/O $n1, $w1
	Duplicate/O $n2, $w2
	Duplicate/O $n3, $w3
	Duplicate/O $n4, $w4
	KillWaves $n0,$n1,$n2,$n3,$n4
	
	if(DataFolderExists("root:Packages:NIST"))
		String/G root:Packages:NIST:gLastFileName = filename
	endif
		
	// assign colors randomly
	rr = abs(trunc(enoise(65535)))
	gg = abs(trunc(enoise(65535)))
	bb = abs(trunc(enoise(65535)))
	
		// if target window is a graph, and user wants to append, do so
	if(WinType("") == 1)
		DoAlert 1,"Do you want to append this data to the current graph?"
		if(V_Flag == 1)
			AppendToGraph $w1 vs $w0
			ModifyGraph mode=3,marker=29,msize=2,rgb ($w1) =(rr,gg,bb),tickUnit=1,grid=1,mirror=2
			ErrorBars/T=0 $w1 Y,wave=($w2,$w2)
		else
		//new graph
			Display $w1 vs $w0
			ModifyGraph log=1,mode=3,marker=29,msize=2,rgb=(rr,gg,bb),tickUnit=1,grid=1,mirror=2
			ErrorBars/T=0 $w1 Y,wave=($w2,$w2)
			Legend
		endif
	else
	// graph window was not target, make new one
		Display $w1 vs $w0
		ModifyGraph log=1,mode=3,marker=29,msize=2,rgb=(rr,gg,bb),tickUnit=1,grid=1,mirror=2
		ErrorBars/T=0 $w1 Y,wave=($w2,$w2)
		Legend
	endif
		
End


//// Extra "Utility Procedures"
// to pick path, get a list of data files, and make sure that a valid filename
// is passed to LoadOneDDataWithName()
//

//prompts user to choose the local folder that contains the SANS Data
//only one folder can be used, and its path is catPathName (and is a NAME, not a string)
//this will overwrite the path selection
//returns 1 if no path selected as error condition
Function A_PickPath()
	
	//set the global string to the selected pathname
	NewPath/O/M="pick the SANS data folder" catPathName
	PathInfo/S catPathName
	String dum = S_path
	String alertStr = ""
	alertStr = "You must set the path to Charlotte through a Mapped Network Drive, not through the Network Neighborhood"
	//alertStr += "  Please see the manual for details."
	if (V_flag == 0)
		//path does not exist - no folder selected
		String/G root:Packages:NIST:gCatPathStr = "no folder selected"
		return(1)
	else
		//set the global to the path (as a string)
		// need 4 \ since it is the escape character
		if(cmpstr("\\\\",dum[0,1])==0)	//Windoze user going through network neighborhood
			DoAlert 0,alertStr
			KillPath catPathName
			return(1)
		endif
		String/G root:Packages:NIST:gCatPathStr = dum
		return(0)		//no error
	endif
End

//Function attempts to find valid filename from partial name that has been stripped of
//the VAX version number. The partial name is tried first
//*** the PATH is hard-wired to catPathName (which is assumed to exist)
//version numers up to ;10 are tried
//only the "name;vers" is returned. the path is not prepended, hence the return string
//is not a complete specification of the file
//
// added 11/99 - uppercase and lowercase versions of the file are tried, if necessary
// since from marquee, the filename field (textread[0]) must be used, and can be a mix of
// upper/lowercase letters, while the filename on the server (should) be all caps
// now makes repeated calls to ValidFileString()
//
Function/S A_FindValidFilename(partialName)
	String PartialName
	
	String retStr=""
	
	//try name with no changes - to allow for ABS files that have spaces in the names 12APR04
	retStr = A_ValidFileString(partialName)
	if(cmpstr(retStr,"") !=0)
		//non-null return
		return(retStr)
	Endif
	
	//if the partial name is derived from the file header, there can be spaces at the beginning
	//or in the middle of the filename - depending on the prefix and initials used
	//
	//remove any leading spaces from the name before starting
	partialName = A_RemoveAllSpaces(partialName)
	
	//try name with no spaces
	retStr = A_ValidFileString(partialName)
	if(cmpstr(retStr,"") !=0)
		//non-null return
		return(retStr)
	Endif
	
	//try all UPPERCASE
	partialName = UpperStr(partialName)
	retStr = A_ValidFileString(partialName)
	if(cmpstr(retStr,"") !=0)
		//non-null return
		return(retStr)
	Endif
	
	//try all lowercase (ret null if failure)
	partialName = LowerStr(partialName)
	retStr = A_ValidFileString(partialName)
	if(cmpstr(retStr,"") !=0)
		//non-null return
		return(retStr)
	else
		return(retStr)
	Endif
End

//function to test a binary file to see if it is a RAW binary SANS file
//first checks the total bytes in the file (which for raw data is 33316 bytes)
//**note that the "DIV" file will also show up as a raw file by the run field
//should be listed in CAT/SHORT and in patch windows
//
//Function then checks the file fname (full path:file) for "RAW" run.type field
//if not found, the data is not raw data and zero is returned
Function A_CheckIfRawData(fname)
	String fname
	
	Variable refnum,totalBytes
	String testStr=""
	
	Open/R/T="????TEXT" refNum as fname
	//get the total number of bytes in the file, to avoid moving past EOF
	FStatus refNum
	totalBytes = V_logEOF
	//Print totalBytes
	if(totalBytes!=33316)
		//can't possibly be a raw data file
		Close refnum
		return(0)		//not a raw SANS file
	Endif
	FSetPos refNum,75
	FReadLine/N=3 refNum,testStr
	Close refNum
	
	if(cmpstr(testStr,"RAW")==0)
		//true, is raw data file
		Return(1)
	else
		//some other file
		Return(0)
	Endif
End

//list (input) is a list, typically returned from IndexedFile()
//which is semicolon-delimited, and may contain filesnames from the VAX
//that contain version numbers, where the version number appears as a separate list item
//(and also as a non-existent file)
//these numbers must be purged from the list, especially for display in a popup
//or list processing of filenames
//the function returns the list, cleaned of version numbers (up to 11)
//raw data files will typically never have a version number other than 1.
Function/S A_RemoveVersNumsFromList(list)
	String list
	
	//get rid of version numbers first (up to 11)
	Variable ii,num
	String item 
	num = ItemsInList(list,";")
	ii=1
	do
		item = num2str(ii)
		list = RemoveFromList(item, list ,";" )
		ii+=1
	while(ii<12)
	
	return (list)
End

//Function attempts to find valid filename from partial name that has been stripped of
//the VAX version number. The partial name is tried first
//*** the PATH is hard-wired to catPathName (which is assumed to exist)
//version numers up to ;10 are tried
//only the "name;vers" is returned. the path is not prepended, hence the return string
//is not a complete specification of the file
//
Function/S A_ValidFileString(partialName)
	String partialName
	
	String tempName = "",msg=""
	Variable ii,refnum
	
	ii=0
	do
		if(ii==0)
			//first pass, try the partialName
			tempName = partialName
			Open/Z/R/T="????TEXT"/P=catPathName refnum tempName	//Does open file (/Z flag)
			if(V_flag == 0)
				//file exists
				Close refnum		//YES needed, 
				break
			endif
		else
			tempName = partialName + ";" + num2str(ii)
			Open/Z/R/T="????TEXT"/P=catPathName refnum tempName
			if(V_flag == 0)
				//file exists
				Close refnum
				break
			endif
		Endif
		ii+=1
		//print "ii=",ii
	while(ii<11)
	//go get the selected bits of information, using tempName, which exists
	if(ii>=11)
		//msg = partialName + " not found. is version number > 11?"
		//DoAlert 0, msg
		//PathInfo catPathName
		//Print S_Path
		Return ("")		//use null string as error condition
	Endif
	
	Return (tempName)
End

//function to remove all spaces from names when searching for filenames
//the filename (as saved) will never have interior spaces (TTTTTnnn_AB _Bnnn)
//but the text field in the header WILL, if less than 3 characters were used for the 
//user's initials, and can have leading spaces if prefix was less than 5 characters
//
//returns a string identical to the original string, except with the interior spaces removed
//
Function/S A_RemoveAllSpaces(str)
	String str
	
	String tempstr = str
	Variable ii,spc,len		//should never be more than 2 or 3 trailing spaces in a filename
	ii=0
	do
		len = strlen(tempStr)
		spc = strsearch(tempStr," ",0)		//is the last character a space?
		if (spc == -1)
			break		//no more spaces found, get out
		endif
		str = tempstr
		tempStr = str[0,(spc-1)] + str[(spc+1),(len-1)]	//remove the space from the string
	While(1)	//should never be more than 2 or 3
	
	If(strlen(tempStr) < 1)
		tempStr = ""		//be sure to return a null string if problem found
	Endif
	
	//Print strlen(tempstr)
	
	Return(tempStr)
		
End

//AJJ Oct 2008
//Moved from GaussUtils - makes more sense to have it here

// utility used in the "PlotSmeared...() macros to get a list of data folders
//
//1:	Waves.
//2:	Numeric variables.
//3:	String variables.
//4:	Data folders.
Function/S GetAList(type)
	Variable type
	
	SetDataFolder root:
	
	String objName,str=""
	Variable index = 0
	do
		objName = GetIndexedObjName(":", type, index)
		if (strlen(objName) == 0)
			break
		endif
		//Print objName
		str += objName + ";"
		index += 1
	while(1)
	
	// remove myGlobals, Packages, etc. from the folder list
	if(type==4)
		str = RemoveFromList("myGlobals", str , ";" )
		str = RemoveFromList("Packages", str, ";")
		str = RemoveFromList("AutoFit", str, ";")
		str = RemoveFromList("TISANE", str, ";")
		str = RemoveFromList("HayPenMSA", str, ";")
		str = RemoveFromList("SAS", str, ";")			//from Irena
		str = RemoveFromList("USAXS", str, ";")
		str = RemoveFromList("RAW;SAM;EMP;BGD;DIV;MSK;ABS;CAL;COR;STO;SUB;DRK;SAS;", str  ,";")			//root level folders present in old reduction experiments
	endif
	
	return(str)
End


//returns the path to the file, or null if cancel
//
// either the T="????" or the /F flags work to set the filter to "all files"
// but the T is essentially obsolete, /F is new for Igor 6.1 and recommended
Function/S DoOpenFileDialog(msg)
	String msg
	
	Variable refNum
//	String message = "Select a file"
	String outputPath
	
	String fileFilters = "All Files:.*;"
		
//	Open/D/R/T="????"/M=msg refNum
	Open/D/R/F=fileFilters/M=msg refNum
	outputPath = S_fileName
	
	return outputPath
End

// returns the path to the file, or null if the user cancelled
// fancy use of optional parameters
// 
// enforce short file names (25 characters)
Function/S DoSaveFileDialog(msg,[fname,suffix])
	String msg,fname,suffix
	Variable refNum
//	String message = "Save the file as"

	if(ParamIsDefault(fname))
//		Print "fname not supplied"
		fname = ""
	endif
	if(ParamIsDefault(suffix))
//		Print "suffix not supplied"
		suffix = ""
	endif
	
	String outputPath,tmpName,testStr
	Variable badLength=0,maxLength=25,l1,l2
	
	
	tmpName = fname + suffix
	
	do
		badLength=0
		Open/D/M=msg/T="????" refNum as tmpName		//OS will allow 255 characters, but then I can't read it back in!
		outputPath = S_fileName
		
		testStr = ParseFilePath(0, outputPath, ":", 1, 0)		//just the filename
		if(strlen(testStr)==0)
			break		//cancel, allow exit
		endif
		if(strlen(testStr) > maxLength)
			badlength = 1
			DoAlert 2,"File name is too long. Is\r"+testStr[0,maxLength-1]+"\rOK?"
			if(V_flag==3)
				outputPath = ""
				break
			endif
			if(V_flag==1)			//my suggested name is OK, so trim the output
				badlength=0
				l1 = strlen(testStr)		//too long length
				l1 = l1-maxLength		//number to trim
				//Print outputPath
				l2=strlen(outputPath)
				outputPath = outputPath[0,l2-1-l1]
				//Print "modified  ",outputPath
			endif
			//if(V_flag==2)  do nothing, let it go around again
		endif
		
	while(badLength)
	
	return outputPath
End

// returns a shortened file name (26 characters max) so that the loader
// won't try to create Igor objects that have names that are longer than 31
// 
Function/S ShortFileNameString(inStr)
	String inStr

	String outStr=""
	Variable maxLength=25
	Variable nameTooLong=0
	String/G root:Packages:NIST:gShortNameStr = inStr[0,maxLength-1]
	SVAR newStr = root:Packages:NIST:gShortNameStr

	if(strlen(inStr) <= maxLength)
		return (inStr)		//length OK
	else
		do
			nameTooLong = 0
			
			DoAlert 1,"File name is too long. Is\r"+inStr[0,maxLength-1]+"\rOK?"
			if(V_flag==1)			//my suggested name is OK, so trim the output
				outStr = inStr[0,maxLength-1]
				//Print "modified  ",outStr
				return(outStr)
			endif
	
	
			if(V_flag == 2)		//not OK, do something about it
				
				DoWindow/F ShorterNameInput		//it really shouldn't exist...
				if(V_flag==0)
				
					NewPanel /W=(166,90,666,230) as "Enter a Shorter Name"
					DoWindow/C ShorterNameInput
					SetDrawLayer UserBack
					TitleBox title0,pos={35,8},size={261,20},title=" Enter a shorter file name. It must be 25 characters or less "
					TitleBox title0,fSize=12,fStyle=1
					SetVariable setvar0,pos={21,52},size={300,15},title="New name",value= _STR:newStr
					SetVariable setvar0,proc=ShorterNameSetVarProc,fsize=12
					SetVariable setvar0 valueBackColor=(65535,49151,49151)
					Button button0,pos={259,87},size={60,20},title="Done"
					Button button0,proc=ShorterNameDoneButtonProc
				
				endif
				
				PauseForUser ShorterNameInput
				
				// this really should force a good name, but there could be errors that I'm not catching
//				Print newStr, strlen(newStr)
				nameTooLong = 0
			endif
		
		while (nameTooLong)
		
		return(newStr)
		
	endif
		
End


// for the ShortFileNameString() - PauseForUser to get a shorter file name
Function ShorterNameSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
		
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
				String sv = sva.sval
				if( strlen(sv) > 25 )
					sv= sv[0,24]
					SetVariable  $(sva.ctrlName),win=$(sva.win),value=_STR:sv
					SetVariable setvar0 valueBackColor=(65535,49151,49151)
					Beep
				else
					SetVariable setvar0 valueBackColor=(65535,65535,65535)
				endif
				break
		endswitch
	return 0
End

// for the ShortFileNameString() - PauseForUser to get a shorter file name
Function ShorterNameDoneButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	String win = ba.win

	switch (ba.eventCode)
		case 2:
			SVAR newStr = root:Packages:NIST:gShortNameStr
			ControlInfo setvar0
			newStr = S_value
			DoWindow/K ShorterNameInput
			
			break
	endswitch

	return 0
End


// a function common to many panels, so put the basic version here that simply
// returns null string if no functions are present. Calling procedures can 
// add to the list to customize as needed.
// show the available models
// not the f*(cw,xw) point calculations
// not the *X(cw,xw) XOPS
//
// KIND:10 should show only user-defined curve fitting functions
// - not XOPs
// - not other user-defined functions
Function/S User_FunctionPopupList()
	String list,tmp
	list = FunctionList("*",";","KIND:10")		//get every user defined curve fit function

	//now start to remove everything the user doesn't need to see...

	tmp = FunctionList("*_proto",";","KIND:10")		//prototypes
	list = RemoveFromList(tmp, list  ,";")
	
	//prototypes that show up if GF is loaded
	list = RemoveFromList("GFFitFuncTemplate", list)
	list = RemoveFromList("GFFitAllAtOnceTemplate", list)
	list = RemoveFromList("NewGlblFitFunc", list)
	list = RemoveFromList("NewGlblFitFuncAllAtOnce", list)
	list = RemoveFromList("GlobalFitFunc", list)
	list = RemoveFromList("GlobalFitAllAtOnce", list)
	list = RemoveFromList("GFFitAAOStructTemplate", list)
	list = RemoveFromList("NewGF_SetXWaveInList", list)
	list = RemoveFromList("NewGlblFitFuncAAOStruct", list)
	
	// more to remove as a result of 2D/Gizmo
	list = RemoveFromList("A_WMRunLessThanDelta", list)
	list = RemoveFromList("WMFindNaNValue", list)
	list = RemoveFromList("WM_Make3DBarChartParametricWave", list)
	list = RemoveFromList("UpdateQxQy2Mat", list)
	list = RemoveFromList("MakeBSMask", list)
	
	// MOTOFIT/GenFit bits
	tmp = "GEN_allatoncefitfunc;GEN_fitfunc;GetCheckBoxesState;MOTO_GFFitAllAtOnceTemplate;MOTO_GFFitFuncTemplate;MOTO_NewGF_SetXWaveInList;MOTO_NewGlblFitFunc;MOTO_NewGlblFitFuncAllAtOnce;GeneticFit_UnSmearedModel;GeneticFit_SmearedModel;"
	list = RemoveFromList(tmp, list  ,";")

	// SANS Reduction bits
	tmp = "ASStandardFunction;Ann_1D_Graph;Avg_1D_Graph;BStandardFunction;CStandardFunction;Draw_Plot1D;MyMat2XYZ;"
	list = RemoveFromList(tmp, list  ,";")
	tmp = "NewDirection;SANSModelAAO_MCproto;Monte_SANS_Threaded;Monte_SANS_NotThreaded;Monte_SANS_W1;Monte_SANS_W2;Monte_SANS_W3;Monte_SANS_W4;Monte_SANS;FractionReachingDetector;TwoLevel_EC;SmearedTwoLevel_EC;"
	list = RemoveFromList(tmp, list  ,";")


	// USANS Reduction bits
	tmp = "DSM_Guinier_Fit;RemoveMaskedPoints;"
	list = RemoveFromList(tmp, list  ,";")

	//more functions from analysis models (2008)
	tmp = "Barbell_Inner;Barbell_Outer;Barbell_integrand;BCC_Integrand;Integrand_BCC_Inner;Integrand_BCC_Outer;"
	list = RemoveFromList(tmp, list  ,";")
	tmp = "CapCyl;CapCyl_Inner;CapCyl_Outer;ConvLens;ConvLens_Inner;ConvLens_Outer;"
	list = RemoveFromList(tmp, list  ,";")
	tmp = "Dumb;Dumb_Inner;Dumb_Outer;FCC_Integrand;Integrand_FCC_Inner;Integrand_FCC_Outer;"
	list = RemoveFromList(tmp, list  ,";")
	tmp = "Integrand_SC_Inner;Integrand_SC_Outer;SC_Integrand;SphCyl;SphCyl_Inner;SphCyl_Outer;"
	list = RemoveFromList(tmp, list  ,";")
	tmp = "CSPP_Outer;CSPP_Inner;PP_Outer;PP_Inner;"
	list = RemoveFromList(tmp, list  ,";")
	tmp = "Guinier_Fit;"
	list = RemoveFromList(tmp, list  ,";")

	tmp = FunctionList("f*",";","NPARAMS:2")		//point calculations
	list = RemoveFromList(tmp, list  ,";")
	
	tmp = FunctionList("fSmear*",";","NPARAMS:3")		//smeared dependency calculations
	list = RemoveFromList(tmp, list  ,";")
	
	// anything that might be included in Irena
	tmp = FunctionList("GEN_*",";","KIND:10")
	list = RemoveFromList(tmp, list  ,";")
	tmp = FunctionList("IN2G_*",";","KIND:10")
	list = RemoveFromList(tmp, list  ,";")
	tmp = FunctionList("IR1A_*",";","KIND:10")
	list = RemoveFromList(tmp, list  ,";")
	tmp = FunctionList("IR1B_*",";","KIND:10")
	list = RemoveFromList(tmp, list  ,";")
	tmp = FunctionList("IR1U_*",";","KIND:10")
	list = RemoveFromList(tmp, list  ,";")
	tmp = FunctionList("IR1V_*",";","KIND:10")
	list = RemoveFromList(tmp, list  ,";")
	tmp = FunctionList("IR1_*",";","KIND:10")
	list = RemoveFromList(tmp, list  ,";")
	tmp = FunctionList("IR2D_*",";","KIND:10")
	list = RemoveFromList(tmp, list  ,";")

	tmp = FunctionList("IR2D_*",";","KIND:10")
	list = RemoveFromList(tmp, list  ,";")
	tmp = FunctionList("IR2H_*",";","KIND:10")
	list = RemoveFromList(tmp, list  ,";")	
	tmp = FunctionList("IR2L_*",";","KIND:10")
	list = RemoveFromList(tmp, list  ,";")
	tmp = FunctionList("IR2Pr_*",";","KIND:10")
	list = RemoveFromList(tmp, list  ,";")
	tmp = FunctionList("IR2R_*",";","KIND:10")
	list = RemoveFromList(tmp, list  ,";")
	tmp = FunctionList("IR2S_*",";","KIND:10")
	list = RemoveFromList(tmp, list  ,";")
	tmp = FunctionList("IR2_*",";","KIND:10")
	list = RemoveFromList(tmp, list  ,";")
	tmp = FunctionList("*LogLog",";","KIND:10")
	list = RemoveFromList(tmp, list  ,";")
	
	//functions included in Nika
	tmp = FunctionList("NI1*",";","KIND:10")
	list = RemoveFromList(tmp, list  ,";")
	tmp = FunctionList("TransAx_*",";","KIND:10")
	list = RemoveFromList(tmp, list  ,";")
	tmp = FunctionList("TransformAxis*",";","KIND:10")
	list = RemoveFromList(tmp, list  ,";")
	tmp = FunctionList("erfForNormal*",";","KIND:10")
	list = RemoveFromList(tmp, list  ,";")

	// functions in Indra (USAXS)
	tmp = FunctionList("IN2Q_*",";","KIND:10")
	list = RemoveFromList(tmp, list  ,";")
	tmp = FunctionList("IN3_*",";","KIND:10")
	list = RemoveFromList(tmp, list  ,";")
	
//	tmp = FunctionList("*X",";","KIND:4")		//XOPs, but these shouldn't show up if KIND:10 is used initially
//	Print "X* = ",tmp
//	print " "
//	list = RemoveFromList(tmp, list  ,";")
	
	//non-fit functions that I can't seem to filter out
	list = RemoveFromList("BinaryHS_PSF11;BinaryHS_PSF12;BinaryHS_PSF22;EllipCyl_Integrand;PP_Inner;PP_Outer;Phi_EC;TaE_Inner;TaE_Outer;",list,";")

	// from 2010 model functions
	list = RemoveFromList("fTwoYukawa;",list,";")
	
	
	list = SortList(list)
	return(list)
End


///////////////////////////////////////////////////
// old SANSPreferences have been moved here to a common place and renamed to "NCNR Preferences" so that they 
// are common to all of the packages (and will appear on all of the menus)
//
// globals moved to root:Packages:NIST: since this is generated by all packages.
//
///////////////////////////
// user preferences
// 
// globals are created in initialize.ipf
//
// this panel allows for user modification
///////////////////////////
Proc Show_Preferences_Panel()

	DoWindow/F Pref_Panel
	if(V_flag==0)
		Initialize_Preferences()
		Pref_Panel()
	Endif
//	Print "Preferences Panel stub"
End

Proc Initialize_Preferences()
	// create the globals here if they are not already present
	
	// each package initialization should call this to repeat the initialization
	// without overwriting what was already set
	
	Variable val
	
	///// items for SANS reduction
	val = NumVarOrDefault("root:Packages:NIST:gLogScalingAsDefault", 1 )
	Variable/G root:Packages:NIST:gLogScalingAsDefault=val
	
	val = NumVarOrDefault("root:Packages:NIST:gAllowDRK", 0 )
	Variable/G root:Packages:NIST:gAllowDRK=val			//don't show DRK as default
	
	val = NumVarOrDefault("root:Packages:NIST:gDoTransCheck", 1 )
	Variable/G root:Packages:NIST:gDoTransCheck=val
	
	val = NumVarOrDefault("root:Packages:NIST:gBinWidth", 1 )
	Variable/G root:Packages:NIST:gBinWidth=val
	
	val = NumVarOrDefault("root:Packages:NIST:gNPhiSteps", 72 )
	Variable/G root:Packages:NIST:gNPhiSteps=val
	
	// flags to turn detector corrections on/off for testing (you should leave these ON)
	val = NumVarOrDefault("root:Packages:NIST:gDoDetectorEffCorr", 1 )
	Variable/G root:Packages:NIST:gDoDetectorEffCorr = 1
	
	val = NumVarOrDefault("root:Packages:NIST:gDoTransmissionCorr", 1 )
	Variable/G root:Packages:NIST:gDoTransmissionCorr = 1
	
	
	/// items for SANS Analysis
	
	
	/// items for USANS Reduction
	
	
	/// items for everyone
	val = NumVarOrDefault("root:Packages:NIST:gXML_Write", 0 )
	Variable/G root:Packages:NIST:gXML_Write = val
	
	
end

Function LogScalePrefCheck(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	
	NVAR gLog = root:Packages:NIST:gLogScalingAsDefault
	glog=checked
	//print "log pref checked = ",checked
End

Function DRKProtocolPref(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	
	NVAR gDRK = root:Packages:NIST:gAllowDRK
	gDRK = checked
	//Print "DRK preference = ",checked
End

Function UnityTransPref(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	
	NVAR gVal = root:Packages:NIST:gDoTransCheck
	gVal = checked
End

Function XMLWritePref(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	
	NVAR gVal = root:Packages:NIST:gXML_Write
	gVal = checked
End

Function PrefDoneButtonProc(ctrlName) : ButtonControl
	String ctrlName
	
	DoWindow/K pref_panel
End

Proc Pref_Panel()
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(646,208,1070,468)/K=2 as "NCNR Preference Panel"
	DoWindow/C pref_panel
	ModifyPanel cbRGB=(49694,61514,27679)
	SetDrawLayer UserBack
	ModifyPanel fixedSize=1
//////
//on main portion of panel, always visible
	Button PrefPanelButtonA,pos={354,12},size={50,20},proc=PrefDoneButtonProc,title="Done"

	TabControl PrefTab,pos={7,49},size={410,202},tabLabel(0)="General",proc=PrefTabProc
	TabControl PrefTab,tabLabel(1)="SANS",tabLabel(2)="USANS",tabLabel(3)="Analysis"
	TabControl PrefTab,value=0
	TabControl PrefTab labelBack=(49694,61514,27679)
	
//on tab(0) - General - initially visible
	CheckBox PrefCtrl_0a,pos={21,96},size={124,14},proc=XMLWritePref,title="Use canSAS XML Output"
	CheckBox PrefCtrl_0a,help={"Checking this will set the default output format to be canSAS XML rather than NIST 6 column"}
	CheckBox PrefCtrl_0a,value= root:Packages:NIST:gXML_Write

//on tab(1) - SANS
	CheckBox PrefCtrl_1a,pos={21,100},size={171,14},proc=LogScalePrefCheck,title="Use Log scaling for 2D data display"
	CheckBox PrefCtrl_1a,help={"Checking this will display 2D SANS data with a logarithmic color scale of neutron counts. If not checked, the color mapping will be linear."}
	CheckBox PrefCtrl_1a,value= root:Packages:NIST:gLogScalingAsDefault
	CheckBox PrefCtrl_1b,pos={21,120},size={163,14},proc=DRKProtocolPref,title="Allow DRK correction in protocols"
	CheckBox PrefCtrl_1b,help={"Checking this will allow DRK correction to be used in reduction protocols. You will need to re-draw the protocol panel for this change to be visible."}
	CheckBox PrefCtrl_1b,value= root:Packages:NIST:gAllowDRK
	CheckBox PrefCtrl_1c,pos={21,140},size={137,14},proc=UnityTransPref,title="Check for Transmission = 1"
	CheckBox PrefCtrl_1c,help={"Checking this will check for SAM or EMP Trans = 1 during data correction"}
	CheckBox PrefCtrl_1c,value= root:Packages:NIST:gDoTransCheck
	SetVariable PrefCtrl_1d,pos={21,170},size={200,15},title="Averaging Bin Width (pixels)"
	SetVariable PrefCtrl_1d,limits={1,100,1},value= root:Packages:NIST:gBinWidth
	SetVariable PrefCtrl_1e,pos={21,195},size={200,15},title="# Phi Steps (annular avg)"
	SetVariable PrefCtrl_1e,limits={1,360,1},value= root:Packages:NIST:gNPhiSteps
	CheckBox PrefCtrl_1f title="Do Transmssion Correction?",size={140,14},value=1
	CheckBox PrefCtrl_1f pos={255,100},help={"TURN OFF ONLY FOR DEBUGGING. This corrects the data for angle dependent transmssion."}
	CheckBox PrefCtrl_1g title="Do Efficiency Correction?",size={140,14}
	CheckBox PrefCtrl_1g value=1,pos={255,120},help={"TURN OFF ONLY FOR DEBUGGING. This corrects the data for angle dependent detector efficiency."}


	CheckBox PrefCtrl_1a,disable=1
	CheckBox PrefCtrl_1b,disable=1
	CheckBox PrefCtrl_1c,disable=1
	SetVariable PrefCtrl_1d,disable=1
	SetVariable PrefCtrl_1e,disable=1
	CheckBox PrefCtrl_1f,disable=1
	CheckBox PrefCtrl_1g,disable=1

//on tab(2) - USANS
	GroupBox PrefCtrl_2a pos={21,100},size={1,1},title="nothing to set",fSize=12

	GroupBox PrefCtrl_2a,disable=1


//on tab(3) - Analysis
	GroupBox PrefCtrl_3a pos={21,100},size={1,1},title="nothing to set",fSize=12
	
	GroupBox PrefCtrl_3a,disable=1

EndMacro

// function to control the drawing of controls in the TabControl on the main panel
// Naming scheme for the controls MUST be strictly adhered to... else controls will 
// appear in odd places...
// all controls are named PrefCtrl_NA where N is the tab number and A is the letter denoting
// the controls position on that particular tab.
// in this way, they will always be drawn correctly..
//
Function PrefTabProc(name,tab)
	String name
	Variable tab
	
//	Print "name,number",name,tab
	String ctrlList = ControlNameList("",";"),item="",nameStr=""
	Variable num = ItemsinList(ctrlList,";"),ii,onTab
	for(ii=0;ii<num;ii+=1)
		//items all start w/"PrefCtrl_", 9 characters
		item=StringFromList(ii, ctrlList ,";")
		nameStr=item[0,8]
		if(cmpstr(nameStr,"PrefCtrl_")==0)
			onTab = str2num(item[9])			//[9] is a number
			ControlInfo $item
			switch(abs(V_flag))	
				case 1:
					Button $item,disable=(tab!=onTab)
					break
				case 2:	
					CheckBox $item,disable=(tab!=onTab)
					break
				case 5:	
					SetVariable $item,disable=(tab!=onTab)
					break
				case 10:	
					TitleBox $item,disable=(tab!=onTab)
					break
				case 4:
					ValDisplay $item,disable=(tab!=onTab)
					break
				case 9:
					GroupBox $item,disable=(tab!=onTab)
					break
				// add more items to the switch if different control types are used
			endswitch
		endif
	endfor 
	return(0)
End

