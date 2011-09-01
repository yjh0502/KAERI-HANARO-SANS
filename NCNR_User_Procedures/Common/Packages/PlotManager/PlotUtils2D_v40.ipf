#pragma rtGlobals=1		// Use modern global access method.
#pragma version=4.00
#pragma IgorVersion=6.1

//
// TO DO:
//
// - more intelligent beam stop masking
// - constraints
// - interactive masking
//
//
// - OCT 2010 	- added fDoBinning_QxQy2D(folderStr) that takes the QxQyQz data and bins it to I(Q)
//   					1D result must still be plotted manually, can be automated later.
//					- for Scaled Image data (QxQy), the function fDoBinning_Scaled2D (in FFT_Cubes) could be
//						modified and added to this file. It was meant for an FFT slice, but applies to 
//						2D model calculations (model_lin) 2D data files as well.


//
// changed June 2010 to read in the resolution information (now 8! columns)
// -- subject to change --
//
// look for either the old-style 3-column (no resolution information) or the newer 8-column format
Proc LoadQxQy()

	LoadWave/G/D/W/A
	String fileName = S_fileName
	String path = S_Path
	Variable numCols = V_flag

	String w0,w1,w2,w3,w4,w5,w6,w7
	String n0,n1,n2,n3,n4,n5,n6,n7
		
	if(numCols == 8)
		// put the names of the 8 loaded waves into local names
		n0 = StringFromList(0, S_waveNames ,";" )
		n1 = StringFromList(1, S_waveNames ,";" )
		n2 = StringFromList(2, S_waveNames ,";" )
		n3 = StringFromList(3, S_waveNames ,";" )
		n4 = StringFromList(4, S_waveNames ,";" )
		n5 = StringFromList(5, S_waveNames ,";" )
		n6 = StringFromList(6, S_waveNames ,";" )
		n7 = StringFromList(7, S_waveNames ,";" )
		
		//remove the semicolon AND period from file names
		w0 = CleanupName((S_fileName + "_qx"),0)
		w1 = CleanupName((S_fileName + "_qy"),0)
		w2 = CleanupName((S_fileName + "_i"),0)
		w3 = CleanupName((S_fileName + "_iErr"),0)
		w4 = CleanupName((S_fileName + "_qz"),0)
		w5 = CleanupName((S_fileName + "_sQpl"),0)
		w6 = CleanupName((S_fileName + "_sQpp"),0)
		w7 = CleanupName((S_fileName + "_fs"),0)
	
		String baseStr=w1[0,strlen(w1)-4]
		if(DataFolderExists("root:"+baseStr))
				DoAlert 1,"The file "+S_filename+" has already been loaded. Do you want to load the new data file, overwriting the data in memory?"
				if(V_flag==2)	//user selected No, don't load the data
					SetDataFolder root:
					KillWaves/Z $n0,$n1,$n2,$n3,$n4,$n5,$n6,$n7		// kill the default waveX that were loaded
					return		//quits the macro
				endif
				SetDataFolder $("root:"+baseStr)
		else
			NewDataFolder/S $("root:"+baseStr)
		endif
		
		//read in the 18 lines of header (18th line starts w/ ASCII... 19th line is blank)
		Make/O/T/N=18 header
		Variable refnum,ii
		string tmpStr=""
		Open/R refNum  as (path+filename)
		ii=0
		do
			tmpStr = ""
			FReadLine refNum, tmpStr
			header[ii] = tmpStr
			ii+=1
		while(ii < 18)		
		Close refnum		
		
		////overwrite the existing data, if it exists
		Duplicate/O $("root:"+n0), $w0
		Duplicate/O $("root:"+n1), $w1
		Duplicate/O $("root:"+n2), $w2
		Duplicate/O $("root:"+n3), $w3
		Duplicate/O $("root:"+n4), $w4
		Duplicate/O $("root:"+n5), $w5
		Duplicate/O $("root:"+n6), $w6
		Duplicate/O $("root:"+n7), $w7
	
	endif		//8-columns
	
	if(numCols == 3)
		// put the names of the 3 loaded waves into local names
		n0 = StringFromList(0, S_waveNames ,";" )
		n1 = StringFromList(1, S_waveNames ,";" )
		n2 = StringFromList(2, S_waveNames ,";" )

		//remove the semicolon AND period from file names
		w0 = CleanupName((S_fileName + "_qx"),0)
		w1 = CleanupName((S_fileName + "_qy"),0)
		w2 = CleanupName((S_fileName + "_i"),0)
		w3 = CleanupName((S_fileName + "_iErr"),0)		//make a name for the error wave, to be generated here

		String baseStr=w1[0,strlen(w1)-4]
		if(DataFolderExists("root:"+baseStr))
				DoAlert 1,"The file "+S_filename+" has already been loaded. Do you want to load the new data file, overwriting the data in memory?"
				if(V_flag==2)	//user selected No, don't load the data
					SetDataFolder root:
					KillWaves/Z $n0,$n1,$n2		// kill the default waveX that were loaded
					return		//quits the macro
				endif
				SetDataFolder $("root:"+baseStr)
		else
			NewDataFolder/S $("root:"+baseStr)
		endif
		
		//read in the 18 lines of header (18th line starts w/ ASCII... 19th line is blank)
		Make/O/T/N=18 header
		Variable refnum,ii
		string tmpStr=""
		Open/R refNum  as (path+filename)
		ii=0
		do
			tmpStr = ""
			FReadLine refNum, tmpStr
			header[ii] = tmpStr
			ii+=1
		while(ii < 18)		
		Close refnum		
		
		////overwrite the existing data, if it exists
		Duplicate/O $("root:"+n0), $w0
		Duplicate/O $("root:"+n1), $w1
		Duplicate/O $("root:"+n2), $w2
	


		// generate my own error wave for I(qx,qy). This is exactly the same procedure that is used in the QxQy_Export function
		Duplicate/O $("root:"+n0), $w3
		$w3 = sqrt($w2)		//assumes Poisson statistics for each cell (counter)
		//	sw = 0.05*sw		// uniform 5% error? tends to favor the low intensity too strongly
		// get rid of the "bad" errorsby replacing the NaN, Inf, and zero with V_avg
		// THIS IS EXTREMEMLY IMPORTANT - if this is not done, there are some "bad" values in the 
		// error wave (things that are not numbers) - and this wrecks the smeared model fitting.
		// It appears to have no effect on the unsmeared model.
		WaveStats/Q $w3
		$w3 = numtype($w3[p]) == 0 ? $w3[p] : V_avg
		$w3 = $w3[p] != 0 ? $w3[p] : V_avg
	
	endif		//3-columns
	
	
	/// do this for all 2D data, whether or not resolution information was read in
	
	Variable/G gIsLogScale = 0
	
	Variable num=numpnts($w0)
	// assume that the Q-grid is "uniform enough" for DISPLAY ONLY
	// use the 3 original waves for all of the fitting...
	ConvertQxQy2Mat($w0,$w1,$w2,baseStr+"_mat")
	Duplicate/O $(baseStr+"_mat"),$(baseStr+"_lin") 		//keep a linear-scaled version of the data
	
	PlotQxQy(baseStr)		//this sets the data folder back to root:!!

	//clean up		
	SetDataFolder root:
	KillWaves/Z $n0,$n1,$n2,$n3,$n4,$n5,$n6,$n7
	
EndMacro

//does not seem to need to be flipped at all from the standard QxQy output
//
// plots the data, as surface0, YellowHot color table
//
Proc PlotQxQy(str)
	String str
	Prompt str,"Pick the data folder containing 2D data",popup,getAList(4)

	PauseUpdate; Silent 1	// Building Gizmo 6 window...

	// Do nothing if the Gizmo XOP is not available.
	if(exists("NewGizmo")!=4)
		DoAlert 0, "Gizmo XOP must be installed"
		return
	endif

	String data = "root:"+str+":"+str+"_mat"
	
	NewGizmo/N=$str/T=str /W=(169,44,495,359)
	ModifyGizmo startRecMacro
	AppendToGizmo Surface=$data,name=surface0

	// for constant color (data is a blue color, lighter on the bottom)
//	ModifyGizmo ModifyObject=surface0 property={ surfaceColorType,1}
//	ModifyGizmo ModifyObject=surface0 property={ srcMode,0}
//	ModifyGizmo ModifyObject=surface0 property={ frontColor,0.749996,0.811093,1,1}
//	ModifyGizmo ModifyObject=surface0 property={ backColor,0.250019,0.433326,1,1}
	//e constant color
	
	//for color table	
	ModifyGizmo ModifyObject=surface0 property={ srcMode,0}
//	ModifyGizmo ModifyObject=surface0 property={ surfaceCTab,Blue}
	ModifyGizmo ModifyObject=surface0 property={ surfaceCTab,ColdWarm}
	ModifyGizmo ModifyObject=surface0 property={ SurfaceCTABScaling,4}
	//e color table
	
	AppendToGizmo Axes=boxAxes,name=axes0
	ModifyGizmo ModifyObject=axes0,property={0,axisRange,-1,-1,-1,1,-1,-1}
	ModifyGizmo ModifyObject=axes0,property={1,axisRange,-1,-1,-1,-1,1,-1}
	ModifyGizmo ModifyObject=axes0,property={2,axisRange,-1,-1,-1,-1,-1,1}
	ModifyGizmo ModifyObject=axes0,property={3,axisRange,-1,1,-1,-1,1,1}
	ModifyGizmo ModifyObject=axes0,property={4,axisRange,1,1,-1,1,1,1}
	ModifyGizmo ModifyObject=axes0,property={5,axisRange,1,-1,-1,1,-1,1}
	ModifyGizmo ModifyObject=axes0,property={6,axisRange,-1,-1,1,-1,1,1}
	ModifyGizmo ModifyObject=axes0,property={7,axisRange,1,-1,1,1,1,1}
	ModifyGizmo ModifyObject=axes0,property={8,axisRange,1,-1,-1,1,1,-1}
	ModifyGizmo ModifyObject=axes0,property={9,axisRange,-1,1,-1,1,1,-1}
	ModifyGizmo ModifyObject=axes0,property={10,axisRange,-1,1,1,1,1,1}
	ModifyGizmo ModifyObject=axes0,property={11,axisRange,-1,-1,1,1,-1,1}
	ModifyGizmo ModifyObject=axes0,property={-1,axisScalingMode,1}
	ModifyGizmo ModifyObject=axes0,property={-1,axisColor,0,0,0,1}
	ModifyGizmo ModifyObject=axes0,property={0,ticks,3}
	ModifyGizmo ModifyObject=axes0,property={1,ticks,3}
	ModifyGizmo ModifyObject=axes0,property={2,ticks,3}
	ModifyGizmo ModifyObject=axes0,property={0,fontScaleFactor,1.5}
	ModifyGizmo ModifyObject=axes0,property={1,fontScaleFactor,1.5}
	ModifyGizmo ModifyObject=axes0,property={2,fontScaleFactor,1.5}
	AppendToGizmo freeAxesCue={0,0,0,1.5},name=freeAxesCue0
	ModifyGizmo setDisplayList=0, opName=clearColor0, operation=clearColor, data={1,0.917,0.75,1}
	ModifyGizmo setDisplayList=1, object=surface0
	ModifyGizmo setDisplayList=2, object=axes0
	ModifyGizmo setDisplayList=3, object=freeAxesCue0
	ModifyGizmo SETQUATERNION={0.521287,-0.097088,-0.138769,0.836408}
	ModifyGizmo autoscaling=1
	ModifyGizmo currentGroupObject=""
	ModifyGizmo compile

	ModifyGizmo NamedHook={GizmoContours,WMGizmoContoursNamedHook}
	ModifyGizmo endRecMacro
	
// don't bother with the flat image plot right now
	
//	Display $yw vs $xw
//	modifygraph log=0
//	ModifyGraph mode=3,marker=16,zColor($yw)={$zw,*,*,YellowHot,0}
//	ModifyGraph standoff=0
//	ModifyGraph width={Aspect,1}
//	ModifyGraph lowTrip=0.001

End

Proc FakeQxQy(minQx,maxQx,minQy,maxQy,numPix,dataFolder)
	Variable minQx=-0.1,maxQx=0.1,minQy=-0.1,maxQy=0.1
	Variable numPix=64
	String dataFolder="fake2DData"

	String baseStr=dataFolder
	

	if(DataFolderExists("root:"+baseStr))
			DoAlert 1,"Fake data "+baseStr+" has already been created. Do you want to overwrite this fake data set?"
			if(V_flag==2)	//user selected No, don't load the data
				SetDataFolder root:
				return		//quits the macro
			endif
			SetDataFolder $("root:"+baseStr)
	else
		NewDataFolder/S $("root:"+baseStr)
	endif

	Make/O/D/N=(numPix*numPix) $(baseStr+"_qx"),$(baseStr+"_qy"),$(baseStr+"_i")
	
	$(baseStr+"_i") = 1
	
	Make/O/D/N=(numPix) tmpX,tmpY
	
	variable delX,delY
	delX = (maxQx - minQx)/numPix
	delY = (maxQy - minQy)/numPix
	tmpX = minQx + x*delX
	tmpY = minQy + x*delY
	
	// get rid of Q=0 values in the waves (may be a bad actor in model calculations)
	//
	tmpX = (tmpX == 0) ? 1e-6 : tmpX
	tmpY = (tmpY == 0) ? 1e-6 : tmpY 
	
	// X wave varies more rapidly
	// Y wave is blocks of values
	Variable ii=0
	do
		$(baseStr+"_qy")[ii*numPix,(ii+1)*numPix] = tmpY[ii]
		ii+=1
	while(ii<numPix)
	
	$(baseStr+"_qx") = tmpX[mod(p,numPix)]
	
	Variable/G gIsLogScale = 0
	
	// assume that the Q-grid is "uniform enough" for DISPLAY ONLY
	// use the 3 original waves for all of the fitting...
	ConvertQxQy2Mat($(baseStr+"_qx"),$(baseStr+"_qy"),$(baseStr+"_i"),baseStr+"_mat")
	Duplicate/O $(baseStr+"_mat"),$(baseStr+"_lin") 		//keep a linear-scaled version of the data
	
	PlotQxQy(baseStr)		//this sets the data folder back to root:!!

	//clean up		
	SetDataFolder root:
	
EndMacro

// this assumes that:
// --QxQy data was written out in the format specified by the Igor macros, that is the x varies most rapidly
// --the matrix is square!
//
// probably some other stuff...
//
Function UpdateQxQy2Mat(Qx,Qy,inten,linMat,mat)
	Wave Qx,Qy,inten,linMat,mat
	
	Variable xrows=DimSize(mat, 0 )			//assumes square matrix!!
	
	String folderStr=GetWavesDataFolder(Qx,1)
	NVAR gIsLogScale=$(folderStr+"gIsLogScale")
	
	linMat = inten[q*xrows+p]
	
	if(gIsLogScale)
		mat = log(linMat)
	else
		mat = linMat
	endif
	
	return(0)
End

// this assumes that:
// --QxQy data was written out in the format specified by the Igor macros, that is the x varies most rapidly
// --the matrix is square!
//
// probably some other stuff...
//
Function ConvertQxQy2Mat(Qx,Qy,inten,matStr)
	Wave Qx,Qy,inten
	String matStr
	
	String folderStr=GetWavesDataFolder(Qx,1)
	
	Variable num=sqrt(numpnts(Qx))		//assumes square matrix, Qx = num x num points long
	Make/O/D/N=(num,num) $(folderStr + matStr)
	Wave mat=$matStr
	
	WaveStats/Q Qx
	SetScale/I x, V_min, V_max, "", mat
	WaveStats/Q Qy
	SetScale/I y, V_min, V_max, "", mat
	
	Variable xrows=num
	
	mat = inten[q*xrows+p]
	
	return(0)
End


//str is the full path to the surface to append
Proc AppendSurfaceToGizmo(str)
	String str
	
	PauseUpdate; Silent 1	// Building Gizmo 6 window...

	AppendToGizmo/Z Surface=$str,name=surface1
	
	// for a constant color (model is darker on top, lighter on the bottom)
	//need these two lines, plus a color
	ModifyGizmo ModifyObject=surface1 property={ surfaceColorType,1}
	ModifyGizmo ModifyObject=surface1 property={ srcMode,0}
	//green
	ModifyGizmo ModifyObject=surface1 property={ frontColor,0.528923,0.882353,0.321584,1}
	ModifyGizmo ModifyObject=surface1 property={ backColor,0.300221,0.6,1.5259e-05,1}
	//red
//	ModifyGizmo ModifyObject=surface1 property={ frontColor,1,0.749996,0.749996,1}
//	ModifyGizmo ModifyObject=surface1 property={ backColor,1,0.250019,0.250019,1}

	ModifyGizmo ModifyObject=surface1 property={ SurfaceCTABScaling,4}
	
	// for a color table (maybe not a good choice for vizualization if data uses a color table)
//	ModifyGizmo ModifyObject=surface1 property={ srcMode,0}
//	ModifyGizmo ModifyObject=surface1 property={ surfaceCTab,Red}
	
//	ModifyGizmo setDisplayList=0, object=surface0
//	ModifyGizmo setDisplayList=1, object=axes0
// object 3 is the axisCue
	ModifyGizmo setDisplayList=4, object=surface1
	ModifyGizmo SETQUATERNION={0.565517,-0.103105,-0.139134,0.806350}
//	ModifyGizmo autoscaling=1
//	ModifyGizmo currentGroupObject=""
	ModifyGizmo compile

//	ModifyGizmo endRecMacro
End

// would be nice, but I can't get this to work...
//
//Macro AdjustColorTables()
//
//	ModifyGizmo ModifyObject=surface1 property={ srcMode,0}
//	ModifyGizmo ModifyObject=surface1 property={ surfaceCTab,Rainbow}
//	ModifyGizmo setDisplayList=3, object=surface1
////	ModifyGizmo SETQUATERNION={0.565517,-0.103105,-0.139134,0.806350}
//	ModifyGizmo autoscaling=1
//	ModifyGizmo currentGroupObject=""
//	ModifyGizmo compile
//	
//end

Function LogToggle2DButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			String winStr=TopGizmoWindow()
			if(strlen(winstr)==0)
				Print "no gizmo window"
				break
			endif
			// the winStr is also the data folder
			// toggle everything in the data folder
			ToggleFolderScaling(winStr)		
			break
	endswitch

	return 0
End

Function Plot2DButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			Execute "PlotQxQy()"
			break
	endswitch

	return 0
End

Function Append2DModelButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			//str is the full path to the surface to append
			String DF=TopGizmoWindow()
			String str,funcStr,suffix
			ControlInfo/W=WrapperPanel popup_1
			funcStr = S_Value
			suffix = getModelSuffix(funcStr)
			if(stringmatch(funcStr, "smear*") == 1)
				suffix = "sm_"+suffix
			endif
			str = "root:"+DF+":"+suffix+"_mat"
			
			Execute "AppendSurfaceToGizmo(\""+str+"\")"
//			Print str
			break
	endswitch

	return 0
End

// toggle the scaling of every matrix in the folder
Function ToggleFolderScaling(DF)
	String DF

	// look for waves DF+"_mat" (the data)
	// and models prefix + "_mat"
	SetDataFolder $("root:"+DF)
	//check the global to see the state of the data
	NVAR gIsLogScale = gIsLogScale
	
	String matrixList=WaveList("*_mat",";",""),item
	Variable ii=0,num=itemsinlist(matrixlist,";"),len
	
	for(ii=0;ii<num;ii+=1)
			item = StringFromList(ii,matrixList,";")
			len = strlen(item)
			Wave w = $item
			Wave linW = $(item[0,len-5]+"_lin")
			if(gisLogScale)
				//make linear
				w=linW
			else	
				//make log scale
				w=log(linW)
				w = w[p][q] == -inf ? NaN : w[p][q]		//remove the -inf for display
			endif
	endfor	
	
	// toggle the global
	gIsLogScale = !gIsLogScale
	
	SetDataFolder root:
	return(0)
End


Function Load2DDataButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			Execute "LoadQxQy()"
			break
	endswitch

	return 0
End


// dispatch the fit
Function Do2DFitButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	String folderStr,funcStr,coefStr
	Variable useCursors,useEps,useConstr
	
	switch( ba.eventCode )
		case 2: // mouse up
			ControlInfo/W=WrapperPanel popup_0
			folderStr=S_Value
			
			ControlInfo/W=WrapperPanel popup_1
			funcStr=S_Value
			
			ControlInfo/W=WrapperPanel popup_2
			coefStr=S_Value
			
			ControlInfo/W=WrapperPanel check_0
			useCursors=V_Value
			//
			// NO CURSORS for 2D waves - force to zero
			//
			useCursors = 0
			//
			ControlInfo/W=WrapperPanel check_1
			useEps=V_Value
			ControlInfo/W=WrapperPanel check_2
			useConstr=V_Value
			
			if(!CheckFunctionAndCoef(funcStr,coefStr))
				DoAlert 0,"The coefficients and function type do not match. Please correct the selections in the popup menus."
				break
			endif
			
			FitWrapper2D(folderStr,funcStr,coefStr,useCursors,useEps,useConstr)
			
			//	DoUpdate (does not work!)
			//?? why do I need to force an update ??
			if(!exists("root:"+folderStr+":"+coefStr))
				Wave w=$coefStr
			else
				Wave w=$("root:"+folderStr+":"+coefStr) //smeared coefs in data folder 
			endif
			w[0] += 1e-6
			w[0] -= 1e-6
	
			break
	endswitch

	return 0
End

// wrapper to do the desired fit, pretty much a clone of FitWrapper, the 1D version
// 
// folderStr is the data folder for the desired data set
//
// Currently the limitations are:
// - I have no error waves for the intensity (fixed 10/2010)
// - There is no smeared model (coming soon after 10/2010)
// - Cursors can't be used
// - the report works OK, but I have little control over the graphics
// - the mask is generated here with a default radius of 8 pixels around the beam center
//
Function FitWrapper2D(folderStr,funcStr,coefStr,useCursors,useEps,useConstr)
	String folderStr,funcStr,coefStr
	Variable useCursors,useEps,useConstr

	//These only make sense for the 1D fits, but put them here so keep the look of the dispatching the same
	Variable useResiduals, useTextBox
	useResiduals = 0
	useTextBox = 0
	
	String suffix=getModelSuffix(funcStr)
	
	SetDataFolder $("root:"+folderStr)
	if(!exists(coefStr))
		// must be unsmeared model, work in the root folder
		SetDataFolder root:				
		if(!exists(coefStr))		//this should be fine if the coef filter is working, but check anyhow
			DoAlert 0,"the coefficient and data sets do not match"
			return 0
		endif
	endif
		
	WAVE cw=$(coefStr)	
	Wave hold=$("Hold_"+suffix)
	Wave/T lolim=$("LoLim_"+suffix)
	Wave/T hilim=$("HiLim_"+suffix)
	Wave eps=$("epsilon_"+suffix)
	
// fill a struct instance whether I need one or not
// note that the resolution waves may or may not exist, and may or may not be used in the fitting
	String DF="root:"+folderStr+":"	
	
	WAVE inten=$(DF+folderStr+"_i")
	WAVE sw=$(DF+folderStr+"_iErr")
	WAVE qx=$(DF+folderStr+"_qx")
	WAVE qy=$(DF+folderStr+"_qy")
	WAVE/Z qz=$(DF+folderStr+"_qz")
	WAVE/Z sQpl=$(DF+folderStr+"_sQpl")
	WAVE/Z sQpp=$(DF+folderStr+"_sQpp")
	WAVE/Z shad=$(DF+folderStr+"_fs")

//just a dummy - I shouldn't need this
	Duplicate/O qx resultW
	resultW=0
	
	STRUCT ResSmear_2D_AAOStruct s
	WAVE s.coefW = cw	
	WAVE s.zw = resultW	
	WAVE s.xw[0] = qx
	WAVE s.xw[1] = qy
	WAVE/Z s.qz = qz
	WAVE/Z s.sQpl = sQpl
	WAVE/Z s.sQpp = sQpp
	WAVE/Z s.fs = shad
	

	// generate my own mask wave - as a matrix first, then redimension to N*N vector
	// default mask is two pixels all the way around, (0 is excluded, 1 is included)
	WAVE DataMat=$(DF+folderStr+"_lin")
	if(exists(DF+"mask") == 0)
		Duplicate/O dataMat mask
		Variable bsRadius=8		//pixels?
		MakeBSMask(mask,bsRadius)
	Endif
	
	
	Duplicate/O inten inten_masked
	inten_masked = (mask[p][q] == 0) ? NaN : inten[p][q]
	

	//for now, use res will always be 0 for 2D functions	
	Variable useResol=0
	if(stringmatch(funcStr, "Smear*"))		// if it's a smeared function, need a struct
		useResol=1
	endif

	// can't use constraints defined as a single text wave for multivariate fits. See the curve fitting help file
	// and "Contraint Matrix and Vector"
	//
	// -- generate a constraint text wave, then the /C flag automatically generates a constraint matrix and vector
	// -- then use the proper logic to dispatch (can't use /NWOK anymore)
	
//	if(useConstr)
//		Print "Constraints not yet implemented"
//		useConstr = 0
//	endif	
//	WAVE/Z constr=constr		//will be a null reference
	
	// do not construct constraints for any of the coefficients that are being held
	// -- this will generate an "unknown error" from the curve fitting
	Make/O/T/N=0 constr
	if(useConstr)
		String constraintExpression
		Variable i, nPnts=DimSize(lolim, 0),nextRow=0
		for (i=0; i < nPnts; i += 1)
			if (strlen(lolim[i]) > 0 && hold[i] == 0)
				InsertPoints nextRow, 1, constr
				sprintf constraintExpression, "K%d > %s", i, lolim[i]
				constr[nextRow] = constraintExpression
				nextRow += 1
			endif
			if (strlen(hilim[i]) > 0 && hold[i] == 0)
				InsertPoints nextRow, 1, constr
				sprintf constraintExpression, "K%d < %s", i, hilim[i]
				constr[nextRow] = constraintExpression
				nextRow += 1
			endif
		endfor

	endif

	if(useCursors)
		Print "Cursors not yet implemented"
		useCursors = 0
	endif	
///// NO CURSORS for 2D waves
	//if useCursors, and the data is USANS, need to feed a (reassigned) trimmed matrix to the fit
	Variable pt1,pt2,newN
	pt1 = 0
	pt2 = numpnts(inten)-1
//	if(useCursors && (dimsize(resW,1) > 4) )
//		if(pcsr(A) > pcsr(B))
//			pt1 = pcsr(B)
//			pt2 = pcsr(A)
//		else
//			pt1 = pcsr(A)
//			pt2 = pcsr(B)
//		endif
//		newN = pt2 - pt1 + 1		// +1 includes both cursors in the fit
//		Make/O/D/N=(newN,newN) $(DF+"crsrResW")
//		WAVE crsrResW = $(DF+"crsrResW")
//		crsrResW = resW[p+pt1][q+pt1]
//		//assign to the struct
//		WAVE fs.resW =  crsrResW		
//	endif

// create these variables so that FuncFit will set them on exit
	Variable/G V_FitError=0				//0=no err, 1=error,(2^1+2^0)=3=singular matrix
	Variable/G V_FitQuitReason=0		//0=ok,1=maxiter,2=user stop,3=no chisq decrease
	
// don't use the auto-destination with no flag, it doesn't appear to work correctly
// dispatch the fit
	//	FuncFit/H="11110111111"/NTHR=0 Cylinder2D_D :cyl2d_c_txt:coef_Cyl2D_D  :cyl2d_c_txt:cyl2d_c_txt_i /X={:cyl2d_c_txt:cyl2d_c_txt_qy,:cyl2d_c_txt:cyl2d_c_txt_qx} /W=:cyl2d_c_txt:sw /I=1 /M=:cyl2d_c_txt:mask /D 
	Variable t1=StopMSTimer(-2)
	Variable tb = 0		//no textbox

// /NTHR=1 means just one thread for the fit (since the function itself is threaded)
// NTHR = 0 == "Auto" mode, using as many processors as are available (not appropriate here since the function itself is threaded?)

	do
	
			// now useEps, and useConstr are all handled w/ /NWOK, just like FitWrapper
			// useCursors needs to have the /C flag in the command for the constraint matrix and vector to be auto-generated

//		if(useResol && useResiduals && useTextBox)		//do it all
//			FuncFit/H=getHStr(hold) /NTHR=0 /TBOX=(tb) $funcStr cw, inten[pt1,pt2] /X={Qx,Qy} /M=mask /W=sw /I=1 /E=eps /C=constr /STRC=s /R /NWOK
//			break
//		endif
//		
//		if(useResol && useResiduals)		//res + resid
//			FuncFit/H=getHStr(hold) /NTHR=0 $funcStr cw, inten[pt1,pt2] /X={Qx,Qy} /M=mask /W=sw /I=1 /E=eps /C=constr /STRC=s /R /NWOK
//			break
//		endif
//
//		
//		if(useResol && useTextBox)		//res + text
//			FuncFit/H=getHStr(hold) /NTHR=0 /TBOX=(tb) $funcStr cw, inten[pt1,pt2] /X={Qx,Qy} /M=mask /W=sw /I=1 /E=eps /C=constr /STRC=s /NWOK
//			break
//		endif
		
		if(useResol && useConstr)		//res  and constraints
			Print "useRes only"
			FuncFit/C/H=getHStr(hold) /NTHR=0 $funcStr cw, inten[pt1,pt2] /X={Qx,Qy} /M=mask /W=sw /I=1 /E=eps /C=constr /STRC=s /NWOK
			break
		endif
		
		if(useResol)		//res only
			Print "useRes only"
			FuncFit/H=getHStr(hold) /NTHR=0 $funcStr cw, inten[pt1,pt2] /X={Qx,Qy} /M=mask /W=sw /I=1 /E=eps /C=constr /STRC=s /NWOK
			break
		endif
				
/////	same as above, but all without useResol (no /STRC flag)
//		if(useResiduals && useTextBox)		//resid+ text
//			FuncFit/H=getHStr(hold) /NTHR=0 /TBOX=(tb) $funcStr cw, inten[pt1,pt2] /X={Qx,Qy} /M=mask /W=sw /I=1 /E=eps /C=constr /R /NWOK
//			break
//		endif
//		
//		if(useResiduals)		//resid
//			FuncFit/H=getHStr(hold) /NTHR=0 $funcStr cw, inten[pt1,pt2] /X={Qx,Qy} /M=mask /W=sw /I=1 /E=eps /C=constr /R /NWOK
//			break
//		endif
//
//		
//		if(useTextBox)		//text
//			FuncFit/H=getHStr(hold) /NTHR=0 /TBOX=(tb) $funcStr cw, inten[pt1,pt2] /X={Qx,Qy} /M=mask /W=sw /I=1 /E=eps /C=constr /NWOK
//			break
//		endif
		
		if(useConstr)
			FuncFit/C/H=getHStr(hold) /NTHR=0 $funcStr cw, inten[pt1,pt2] /X={Qx,Qy} /M=mask /W=sw /I=1 /E=eps /C=constr /NWOK
			break
		Endif
		
		//just a plain vanilla fit

		FuncFit/H=getHStr(hold) /NTHR=0 $funcStr cw, inten[pt1,pt2] /X={Qx,Qy} /M=mask /W=sw /I=1 /E=eps /C=constr /NWOK
		
	while(0)
	
	Print "elapsed 2D fit time  = ",(StopMSTimer(-2) - t1)/1e6," seconds = ",(StopMSTimer(-2) - t1)/1e6/60," minutes"

	// append the fit
	// need to manage duplicate copies
	// Don't plot the full curve if cursors were used (set fitYw to NaN on entry...)
//	String traces=TraceNameList("", ";", 1 )		//"" as first parameter == look on the target graph
//	if(strsearch(traces,"FitYw",0) == -1)
//		AppendToGraph FitYw vs xw
//	else
//		RemoveFromGraph FitYw
//		AppendToGraph FitYw vs xw
//	endif
//	ModifyGraph lsize(FitYw)=2,rgb(FitYw)=(0,0,0)
	
//	DoUpdate		//force update of table and graph with fitted values (why doesn't this work? - the table still does not update)
	
	// report the results (to the panel?)
	print "V_chisq = ",V_chisq
	print cw
	WAVE w_sigma
	print w_sigma
	String resultStr=""
	
	if(waveexists(W_sigma))
		//append it to the table, if it's not already there
		CheckDisplayed/W=WrapperPanel#T0 W_sigma
		if(V_flag==0)
			//not there, append it
			AppendtoTable/W=wrapperPanel#T0 W_sigma
		else
			//remove it, and put it back on to make sure it's the right one (do I need to do this?)
			// -- not really, since any switch of the function menu takes W_Sigma off
		endif
	endif
		
	//now re-write the results
	sprintf resultStr,"Chi^2 = %g  Sqrt(X^2/N) = %g",V_chisq,sqrt(V_chisq/V_Npnts)
	resultStr = PadString(resultStr,63,0x20)
	GroupBox grpBox_2 title=resultStr
	ControlUpdate/W=WrapperPanel grpBox_2
	sprintf resultStr,"FitErr = %s : FitQuit = %s",W_ErrorMessage(V_FitError),W_QuitMessage(V_FitQuitReason)
	resultStr = PadString(resultStr,63,0x20)
	GroupBox grpBox_3 title=resultStr
	ControlUpdate/W=WrapperPanel grpBox_3
	
	Variable yesSave=0,yesReport=0
	ControlInfo/W=WrapperPanel check_4
	yesReport = V_Value
	ControlInfo/W=WrapperPanel check_5
	yesSave = V_Value
	
	
	if(yesReport)
		String parStr = getFunctionParams(funcStr)
//		String parStr=GetWavesDataFolder(cw,1)+ WaveList("*param*"+suffix, "", "TEXT:1," )		//old way, but doesn't work in 2D folders
		String topGraph= TopGizmoWindow()  	//this is the topmost Gizmo (XOP) window
		
		DoUpdate		//force an update of the graph before making a copy of it for the report
	
		W_GenerateReport(funcStr,folderStr,$parStr,cw,yesSave,V_chisq,W_sigma,V_npnts,V_FitError,V_FitQuitReason,V_startRow,V_endRow,topGraph)
	endif
	
	SetDataFolder root:
	return(0)
End


// right now, there are only unsmeared models, but I want experimental points
// for the QxQy of the calculation - so get the folder string
Function Plot2DFunctionButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	String folderStr,funcStr,coefStr,cmdStr=""
	
	Variable killWhat=0		//kill nothing as default

	switch( ba.eventCode )
		case 2: // mouse up
			ControlInfo/W=WrapperPanel popup_0
			folderStr=S_Value
			
			ControlInfo/W=WrapperPanel popup_1
			funcStr=S_Value
			
			// check for smeared or smeared function
//			if(stringmatch(funcStr, "Smear*" )==1)
				//it's a smeared model
				// check for the special case of RPA that has an extra parameter
//				if(strsearch(funcStr, "RPAForm", 0 ,0) == -1)
					sprintf cmdStr, "Plot%s(\"%s\")",funcStr,folderStr		//not RPA
//				else
//					sprintf cmdStr, "Plot%s(\"%s\",)",funcStr,folderStr		//yes RPA, leave a comma for input
//				endif
//			else
//				// it's not, 			
//				sprintf cmdStr, "Plot%s()",funcStr
//			endif
			
			//Print cmdStr
			Execute cmdStr
			
			//pop the function menu to set the proper coefficients
			DoWindow/F WrapperPanel
			STRUCT WMPopupAction pa
			pa.popStr = funcStr
			pa.eventcode = 2
			Function_PopMenuProc(pa)
	
			KillWhat = 2 		//kill just the table, leave the 2d visible for now
			KillTopGraphAndTable(killWhat)		// crude

			break
	endswitch

	return 0
End

// unused - all of this functionality has been added to the Wrapper Panel
Window Plot_2D_Controls()
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(950,44,1250,244)
	Button button0,pos={172,37},size={70,20},proc=LogToggle2DButtonProc,title="Log/Lin"
	Button button1,pos={146,9},size={100,20},proc=Plot2DButtonProc,title="Plot 2D Data"
	Button button2,pos={164,118},size={120,20},proc=Append2DModelButtonProc,title="Append Model"
	PopupMenu popup_1,pos={9,84},size={132,20},proc=Function_PopMenuProc,title="Function"
	PopupMenu popup_1,mode=1,popvalue="Cylinder2D",value= #"W_FunctionPopupList()"
	Button button3,pos={11,9},size={100,20},proc=Load2DDataButtonProc,title="Load 2D Data"
	Button button4,pos={164,161},size={120,20},proc=Do2DFitButtonProc,title="Do 2D Fit"
	Button button5,pos={164,85},size={120,20},proc=Plot2DFunctionButtonProc,title="Plot 2D Function"
EndMacro


Function/S TopGizmoWindow()
	Return(StringFromList(0,WinList("*",";","WIN:4096")))
end

////
//
// unused proc for testing
Proc Plot2DVsPointNumber(str)
	String str
	Prompt str,"Pick the data folder containing 2D data",popup,getAList(4)

	PauseUpdate; Silent 1		// building window...
	String fldrSav0= GetDataFolder(1)
	SetDataFolder $("root:"+str)
	Display /W=(241,352,810,842) $(str+"_i")
	SetDataFolder fldrSav0
	ModifyGraph mode=3
	ModifyGraph marker=19
	ModifyGraph lSize=2
	ModifyGraph rgb($(str+"_i"))=(0,0,0)
	ModifyGraph msize=1
	ModifyGraph grid=1
	ModifyGraph log(left)=1
	ModifyGraph mirror=2
	if(exists("root:"+str+":sw"))
		ErrorBars/T=0 $(str+"_i") Y,wave=($("root:"+str+":sw"),$("root:"+str+":sw"))
	endif
	SetDataFolder fldrSav0
EndMacro

// testing procedure, used when I had x,y swapped and was getting nonsensical results
//Macro CalculateChiSquared(str)
//	String str
//	Prompt str,"Pick the data folder containing 2D data",popup,getAList(4)
//
//
//	String fldrSav0= GetDataFolder(1)
//	SetDataFolder $("root:"+str)
//
//	Duplicate/O $(str+"_i") chi
//	chi = ((zwave_cyl2D_D - $(str+"_i"))/sw )^2
//	
//	chi = (mask == 1) ? chi : 0
//	
//	Print sum(chi,-inf,inf)
//	
//	SetDataFolder fldrSav0
//EndMacro


Function MakeBSMask(mask,rad)
	Wave mask
	Variable rad


// find the center based on the wave scaling
	Variable xCtr,yCtr,Qzero=0
	xCtr = (Qzero - DimOffset(Mask, 0))/DimDelta(Mask,0)
	yCtr = (Qzero - DimOffset(Mask, 1))/DimDelta(Mask,1)

	Print xctr,yctr

//	Variable center = sqrt(numpnts(mask))/2 -0.5

	mask = (sqrt((p-xCtr)^2+(q-yCtr)^2) < rad) ? 0 : 1

	Variable xDim, yDim
	xDim = DimSize(mask,0)
	yDim = DimSize(mask,1)
	mask[][0] = 0
	mask[][1] = 0
	mask[][yDim-2] = 0
	mask[][yDim-1] = 0
	mask[0][] = 0
	mask[1][] = 0
	mask[xDim-2][] = 0
	mask[xDim-1][] = 0
	
	Redimension/N=(xDim*yDim) mask		//now 1D
	
	
End

// This routine assumes that the 2D data was loaded with the NCNR loader, so that the
// data is in a data folder, and the extensions are known. A more generic form could 
// be made too, if needed.
//
// X- need error on I(q)
// -- need to set "proper" number of data points (delta and qMax?)
// X- need to remove points at high Q end
//
// -- like the routines in CircSectAve, start with 500 points, and trim after binning is done.
// 	you'l end up with < 200 points.
//
// the results are in iBin_qxqy, qBin_qxqy, and eBin_qxqy, in the folder passed
// 
//Function fDoBinning_QxQy2D(inten,qx,qy,qz)
Function fDoBinning_QxQy2D(folderStr)
	String folderStr

//	Wave inten,qx,qy,qz

	SetDataFolder $("root:"+folderStr)
	
	WAVE inten = $(folderStr + "_i")
	WAVE qx = $(folderStr + "_qx")
	WAVE qy = $(folderStr + "_qy")
	WAVE qz = $(folderStr + "_qz")
	
	Variable xDim=numpnts(qx),yDim
	Variable ii,jj,delQ
	Variable qTot,nq,var,avesq,aveisq
	Variable binIndex,val
	
	nq = 500
	
	yDim = XDim
	Make/O/D/N=(nq) iBin_qxqy,qBin_qxqy,nBin_qxqy,iBin2_qxqy,eBin_qxqy
	delQ = abs(sqrt(qx[2]^2+qy[2]^2+qz[2]^2) - sqrt(qx[1]^2+qy[1]^2+qz[1]^2))		//use bins of 1 pixel width 
	qBin_qxqy[] =  p*	delQ	
	SetScale/P x,0,delQ,"",qBin_qxqy		//allows easy binning

	iBin_qxqy = 0
	iBin2_qxqy = 0
	eBin_qxqy = 0
	nBin_qxqy = 0	//number of intensities added to each bin
	
	for(ii=0;ii<xDim;ii+=1)
		qTot = sqrt(qx[ii]^2 + qy[ii]^2+ qz[ii]^2)
		binIndex = trunc(x2pnt(qBin_qxqy, qTot))
		val = inten[ii]
		if (numType(val)==0)		//count only the good points, ignore Nan or Inf
			iBin_qxqy[binIndex] += val
			iBin2_qxqy[binIndex] += val*val
			nBin_qxqy[binIndex] += 1
		endif
	endfor

//calculate errors, just like in CircSectAve.ipf
	for(ii=0;ii<nq;ii+=1)
		if(nBin_qxqy[ii] == 0)
			//no pixels in annuli, data unknown
			iBin_qxqy[ii] = 0
			eBin_qxqy[ii] = 1
		else
			if(nBin_qxqy[ii] <= 1)
				//need more than one pixel to determine error
				iBin_qxqy[ii] /= nBin_qxqy[ii]
				eBin_qxqy[ii] = 1
			else
				//assume that the intensity in each pixel in annuli is normally
				// distributed about mean...
				iBin_qxqy[ii] /= nBin_qxqy[ii]
				avesq = iBin_qxqy[ii]^2
				aveisq = iBin2_qxqy[ii]/nBin_qxqy[ii]
				var = aveisq-avesq
				if(var<=0)
					eBin_qxqy[ii] = 1e-6
				else
					eBin_qxqy[ii] = sqrt(var/(nBin_qxqy[ii] - 1))
				endif
			endif
		endif
	endfor
	
	// find the last non-zero point, working backwards
	val=nq
	do
		val -= 1
	while(nBin_qxqy[val] == 0)
	
//	print val, nBin_qxqy[val]
	DeletePoints val, nq-val, iBin_qxqy,qBin_qxqy,nBin_qxqy,iBin2_qxqy,eBin_qxqy
	
	SetDataFolder root:
	
	return(0)
End