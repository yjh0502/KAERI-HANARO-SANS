#pragma rtGlobals=1		// Use modern global access method.
#pragma IgorVersion=4.0
#pragma version=3.00

//************************
//
// Utility procedure to allow the user to select exactly which fitting
// functions they wish to include in their experiment. Smearing and plotting
// procedures are automatically included
//
// Functions are now in "SANS Models" Menu, with submenus for
// smeared/unsmeared functions
//
// this change was prompted due to the 31 item limitation of Windows submenus
// resulting in functions being unavailable in the curve fitting dialog
//
// A built-in list of procedure files is included, and should match the current
// distribution package -- see the procedure asdf() for instructions on how
// to update the built-in list of procedures
//
// SRK 091801
//
// Updated for easier use 02 JUL 04 SRK
//
// SRK 16DEC05 added utility function to get the list of all functions
// first - select and include all of the models
//    -- Proc GetAllModelFunctions()
//
// SEE TypeNewModelList() for instructions on how to permanently add new model
// functions to the list... (APR 06 SRK)
//
// added Freeze Model - to duplicate a model function/strip the dependency
// and plot it on the top graph - so that parameters can be changed...
// SRK 09 JUN 2006
//
//***************************

// main procedure for invoking the Procedure list panel
// initializes each time to make sure
Proc ModelPicker_Panel()

	Variable/G root:SANS_ANA_VERSION=3.00
	
	DoWindow/F Procedure_List
	if(V_Flag==0)
		Init_FileList()
		Procedure_List()
	endif
End

// initialization procedure to create the necessary data folder and the waves for
// the list box in the panel
Proc Init_FileList()
	//create the data folder
	if(!DataFolderExists("root:FileList"))
		NewDataFolder/O/S root:FileList
		//create the waves
		Make/O/T/N=0 fileWave,includedFileWave
		Make/O/N=0 selWave,selToDelWave
	//	String/G allFiles=""
		String/G MenuItemStr1=""
		String/G MenuItemStr2=""
		//DON'T create MenuItemStr_def 
		
		// a switch for me to turn off file checking
		Variable/G checkForFiles=1		//set to true initially
		
		//fill the list of procedures
		//
		// first time, create wave from built-in list
		FileList_BuiltInList()		//makes sure that the wave exists
		FileList_GetListButtonProc("")	//converts it into a list for the panel
		
		// "include" nothing to force a load of the utility procedures
		FileList_InsertButtonProc("") 
		
		NewDataFolder/O root:myGlobals		//others will need this...make it just in case
		
		SetDataFolder root:
	Endif
End


// for my own testing to read in a new list of procedures
// FileList_GetListButtonProc("") will only read in a new list
// if the wave SANS_Model_List does not exist
Proc ReadNewProcList()
	KillWaves/Z root:FileList:SANS_Model_List		//kill the old list
	FileList_GetListButtonProc("")
End

// To create a new "Built-in" list of procedures, edit the 
// wave SANS_Model_List (a text wave), adding your new procedure names
// (sort alphabetically if desired)
// then use TypeNewModelList() to spit out the text format.
// then paste this list into FileList_BuiltInList
//
// note that you won't have help for these new procedures until 
// you update the function documentation, making the name of the procedure
// file a Subtopic
//
Proc TypeNewModelList()
	variable ii=0,num=numpnts(root:FileList:SANS_Model_List)
	printf "Make/O/T/N/=%d  SANS_Model_List\r\r",num
	do
		printf "SANS_Model_List[%d] = \"%s\"\r",ii,root:FileList:SANS_Model_List[ii]
		ii+=1
	while(ii<num)
End

Proc FileList_BuiltInList()
	SetDataFolder root:FileList

////paste here... after deleting the old make statement and list
	
	Make/O/T/N=62 SANS_Model_List
	
  SANS_Model_List[0] = "Beaucage.ipf"
  SANS_Model_List[1] = "BE_Polyelectrolyte.ipf"
  SANS_Model_List[2] = "BimodalSchulzSpheres.ipf"
  SANS_Model_List[3] = "BinaryHardSpheres.ipf"
  SANS_Model_List[4] = "CoreShell.ipf"
  SANS_Model_List[5] = "CoreShellCylinder.ipf"
  SANS_Model_List[6] = "CoreShell_and_Struct.ipf"
  SANS_Model_List[7] = "CylinderForm.ipf"
  SANS_Model_List[8] = "Cylinder_and_Struct.ipf"
  SANS_Model_List[9] = "Cylinder_PolyLength.ipf"
  SANS_Model_List[10] = "Cylinder_PolyRadius.ipf"
  SANS_Model_List[11] = "DAB_model.ipf"
  SANS_Model_List[12] = "Debye.ipf"
  SANS_Model_List[13] = "EllipticalCylinder.ipf"
  SANS_Model_List[14] = "FlexCyl_EllipCross.ipf"
  SANS_Model_List[15] = "FlexCyl_PolyLen.ipf"
  SANS_Model_List[16] = "FlexCyl_PolyRadius.ipf"
  SANS_Model_List[17] = "FlexibleCylinder.ipf"
  SANS_Model_List[18] = "Fractal.ipf"
  SANS_Model_List[19] = "GaussSpheres.ipf"
  SANS_Model_List[20] = "GaussSpheres_and_Struct.ipf"
  SANS_Model_List[21] = "HardSphereStruct.ipf"
  SANS_Model_List[22] = "HollowCylinders.ipf"
  SANS_Model_List[23] = "HPMSA.ipf"
  SANS_Model_List[24] = "LamellarFF.ipf"
  SANS_Model_List[25] = "LamellarFF_HG.ipf"
  SANS_Model_List[26] = "LamellarPS.ipf"
  SANS_Model_List[27] = "LamellarPS_HG.ipf"
  SANS_Model_List[28] = "LogNormalSphere.ipf"
  SANS_Model_List[29] = "LogNormSpheres_and_Struct.ipf"
  SANS_Model_List[30] = "Lorentz_model.ipf"
  SANS_Model_List[31] = "MultiShell.ipf"
  SANS_Model_List[32] = "OblateCS_and_Struct.ipf"
  SANS_Model_List[33] = "OblateForm.ipf"
  SANS_Model_List[34] = "Parallelepiped.ipf"
  SANS_Model_List[35] = "Peak_Gauss_model.ipf"
  SANS_Model_List[36] = "Peak_Lorentz_model.ipf"
  SANS_Model_List[37] = "PolyCore.ipf"
  SANS_Model_List[38] = "PolyCoreShellCylinder.ipf"
  SANS_Model_List[39] = "PolyCoreShellRatio.ipf"
  SANS_Model_List[40] = "PolyCore_and_Struct.ipf"
  SANS_Model_List[41] = "PolyCSRatio_and_Struct.ipf"
  SANS_Model_List[42] = "PolyHardSphereInten.ipf"
  SANS_Model_List[43] = "PolyRectSphere_and_Struct.ipf"
  SANS_Model_List[44] = "Power_Law_model.ipf"
  SANS_Model_List[45] = "ProlateCS_and_Struct.ipf"
  SANS_Model_List[46] = "ProlateForm.ipf"
  SANS_Model_List[47] = "RectPolySpheres.ipf"
  SANS_Model_List[48] = "SchulzSpheres.ipf"
  SANS_Model_List[49] = "SchulzSpheres_and_Struct.ipf"
  SANS_Model_List[50] = "SmearedRPA.ipf"
  SANS_Model_List[51] = "Sphere.ipf"
  SANS_Model_List[52] = "Sphere_and_Struct.ipf"
  SANS_Model_List[53] = "SquareWellStruct.ipf"
  SANS_Model_List[54] = "StackedDiscs.ipf"
  SANS_Model_List[55] = "StickyHardSphereStruct.ipf"
  SANS_Model_List[56] = "Teubner.ipf"
  SANS_Model_List[57] = "TriaxialEllipsoid.ipf"
  SANS_Model_List[58] = "UnifEllipsoid_and_Struct.ipf"
  SANS_Model_List[59] = "UniformEllipsoid.ipf"
  SANS_Model_List[60] = "Vesicle_UL.ipf"
  SANS_Model_List[61] = "Vesicle_UL_and_Struct.ipf"
  
  ///end paste here
End

//another way to add a single procedure name to the list
// (only in the current experiment!)
// not a permanent add to the template, unless you re-save the 
// template
Proc AddProcedureToList(ProcedureName)
	String ProcedureName
	
	SetDataFolder root:FileList
	Variable num
	num=numpnts(fileWave)
	Redimension/N=(num+1) fileWave
	fileWave[num] = ProcedureName
	num=numpnts(selWave)
	Redimension/N=(num+1) selWave
	selWave[num] = 0
	
	SetDataFolder root:
End
/////////////////////////////////////////////////////////////


Proc doCheck(val)
	Variable val
	// a switch for me to turn off file checking
	root:FileList:checkForFiles=val	//0==no check, 1=check	
End


Function MakeMenu_ButtonProc(ctrlName) : ButtonControl
	String ctrlName

	RefreshMenu()
End

//procedure for drawing the simple panel to pick and compile selected models
//
Proc Procedure_List()
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(582,44,920,263) /K=2
	DoWindow/C Procedure_List
	ModifyPanel fixedSize=1
	ListBox fileList,pos={4,3},size={200,100},listWave=root:FileList:fileWave
	ListBox fileList,selWave=root:FileList:selWave,mode= 4
	ListBox inclList,pos={4,110},size={200,100}
	ListBox inclList,listWave=root:FileList:includedFileWave
	ListBox inclList,selWave=root:FileList:selToDelWave,mode= 4
	Button button0,pos={212,77},size={110,20},proc=FileList_InsertButtonProc,title="Include File(s)"
	Button button0,help={"Includes the selected procedures, functions appear under the SANS Models menu"}
	Button button5,pos={212,187},size={110,20},proc=FileList_RemoveButtonProc,title="Remove File(s)"
	Button button5,help={"Removes selected procedures from the experiment"}
	Button PickerButton,pos={212,12},size={90,20},proc=FileList_HelpButtonProc,title="Picker Help"
	Button PickerButton,help={"If you need help understanding what a help button does, you really need help"}
	Button button1,pos={212,35},size={100,20},proc=FileList_HelpButtonProc,title="Function Help"
	Button button1,help={"If you need help understanding what a help button does, you really need help"}
EndMacro

//button function to prompt user to select path where procedures are located
Function FL_PickButtonProc(ctrlName) : ButtonControl
	String ctrlName

	PickProcPath()
End

//bring the help notebook to the front
Function FileList_HelpButtonProc(ctrlName) : ButtonControl
	String ctrlName

	if(cmpstr(ctrlName,"PickerButton")==0)		//PickerButton is the picker help
		DisplayHelpTopic "SANS Model Picker"
		return(0)
	endif
	
	//otherwise, show the help for the selected function	
	//loop through the selected files in the list...
	//
	Wave/T fileWave=$"root:FileList:fileWave"
	Wave sel=$"root:FileList:selWave"
	
	Variable num=numpnts(sel),ii
	String fname=""
	
//	NVAR doCheck=root:FileList:checkForFiles
	ii=num-1		//work bottom-up to not lose the index
	do
		if(sel[ii] == 1)		
				fname = fileWave[ii] //RemoveExten(fileWave[ii])
		endif
		ii-=1
	while(ii>=0)
	
	// nothing selected in the list to include,
	//try the list of already-included files
	if(cmpstr(fname,"")==0)
		Wave/T inclFileWave=$"root:FileList:includedFileWave"
		Wave seltoDel=$"root:FileList:selToDelWave"
		num=numpnts(seltoDel)
		ii=num-1		//work bottom-up to not lose the index
		do
			if(seltoDel[ii] == 1)		
					fname = inclFileWave[ii] //RemoveExten(fileWave[ii])
			endif
			ii-=1
		while(ii>=0)
	endif
	
	if(cmpstr(fname,"")!=0)
//		Print "show help for ",RemoveExten(fname)
//		Print fname[strlen(fname)-11,strlen(fname)-1]
		if(cmpstr(fname[strlen(fname)-11,strlen(fname)-1],"_Struct.ipf") ==0 )
			DisplayHelpTopic "How Form Factors and Structure Factors are Combined"
		else
			DisplayHelpTopic fname
		endif
	else
		DoAlert 0,"Please select a function from the list to display its help file"
	endif
	
	return(0)
End

//closes the panel when done
Function FileListDoneButtonProc(ctrlName) : ButtonControl
	String ctrlName

	//kill the panel
	DoWindow/K Procedure_List
	return(0)
End

//reads in the list of procedures
// (in practice, the list will be part of the experiment)
// but this can be used to easily update the list if
// new models are added, or if a custom list is desired
// - these lists could also be stored in the template
//
Function FileList_GetListButtonProc(ctrlName) : ButtonControl
	String ctrlName
	
	String list=""

	if(Exists("root:FileList:SANS_Model_List") != 1)
		SetDataFolder root:FileList
		LoadWave/A/T
		WAVE/T w=$(StringFromList(0,S_WaveNames,";"))
		SetDataFolder root:
	else
		WAVE/T w=$("root:FileList:SANS_Model_List")
	endif
	
//	// convert the input wave to a semi-list
//	SVAR allFiles=root:FileList:allFiles
//	allFiles=MP_TextWave2SemiList(w)
	list=MP_TextWave2SemiList(w)
	
	//get the list of available files from the specified path
	String newList="",item=""
	Variable num=ItemsInList(list,";"),ii

	// remove the items that have already been included
	Wave/T includedFileWave=$"root:FileList:includedFileWave"
	Variable numInc=numpnts(includedFileWave)
	for(ii=0;ii<numInc;ii+=1)
		list = RemoveFromList(includedFileWave[ii],list,";")
	endfor
	list = SortList(list,";",0)
	num=ItemsInList(list,";")
	WAVE/T fileWave=$"root:FileList:fileWave"
	WAVE selWave=$"root:FileList:selWave"
	Redimension/N=(num) fileWave		//make the waves the proper length
	Redimension/N=(num) selWave
	fileWave = StringFromList(p,list,";")		//converts the list to a wave
	Sort filewave,filewave
	
	return(0)
End

//*******OLD WAY*******
//*******NOT USED*******
//gets the list of files in the folder specified by procPathName
//filters the list to remove some of the procedures that the user does not need to see
// list is assigned to textbox wave
Function OLD_FileList_GetListButtonProc(ctrlName) : ButtonControl
	String ctrlName
	
	//make sure that path exists
	PathInfo procPathName
	if (V_flag == 0)
		//Abort "Folder path does not exist - use Pick Path button to set path"
		//build the path to the User Procedures folder
		PathInfo Igor
	//	Print S_Path
		String UserProcStr=S_path+"User Procedures:"
		NewPath/O/Q procPathName  UserProcStr
	Endif
	
	String list=""
//	list=IndexedFile(procPathName,-1,"????")

// new way, to catch all files in all subfolders
	SVAR allFiles=root:FileList:allFiles
	allFiles=""		//clear the list

	ListAllFilesAndFolders("procPathName",1,1,0)	//this sets allFiles
	list = allFiles
	
	//get the list of available files from the specified path
	
	String newList="",item=""
	Variable num=ItemsInList(list,";"),ii
	//remove procedures from the list the are unrelated, or may be loaded by default (Utils)
	list = RemoveFromList(".DS_Store",list,";")		//occurs on OSX, not "hidden" to Igor
	list = RemoveFromList("GaussUtils.ipf",list,";" )
	list = RemoveFromList("PlotUtils.ipf",list,";" )
	list = RemoveFromList("PlotUtilsMacro.ipf",list,";" )
	list = RemoveFromList("WriteModelData.ipf",list,";" )
	list = RemoveFromList("WMMenus.ipf",list,";" )
	list = RemoveFromList("DemoLoader.ipf",list,";" )
	// remove the items that have already been included
	Wave/T includedFileWave=$"root:FileList:includedFileWave"
	Variable numInc=numpnts(includedFileWave)
	for(ii=0;ii<numInc;ii+=1)
		list = RemoveFromList(includedFileWave[ii],list,";")
	endfor
	list = SortList(list,";",0)
	num=ItemsInList(list,";")
	WAVE/T fileWave=$"root:FileList:fileWave"
	WAVE selWave=$"root:FileList:selWave"
	Redimension/N=(num) fileWave		//make the waves the proper length
	Redimension/N=(num) selWave
	fileWave = StringFromList(p,list,";")		//converts the list to a wave
	Sort filewave,filewave
End

// returns 1 if the file exists, 0 if the file is not there
// fails miserably if there are aliases in the UP folder, although
// the #include doesn't mind
Function CheckFileInUPFolder(fileStr)
	String fileStr

	Variable err=0
	String/G root:FileList:allFiles=""
	SVAR allFiles = root:FileList:allFiles
	
	PathInfo Igor
	String UPStr=S_path+"User Procedures:"
	NewPath /O/Q/Z UPPath ,UPStr
	ListAllFilesAndFolders("UPPath",1,1,0)	//this sets allFiles
	String list = allFiles
//	err = FindListItem(fileStr, list ,";" ,0)
//	err = strsearch(list, fileStr, 0,2)		//this is not case-sensitive, but Igor 5!
	err = strsearch(list, fileStr, 0)		//this is Igor 4+ compatible
//	Print err
	if(err == -1)
		return(0)
	else
		return(1)		//name was found somewhere
	endif
End


Function FileList_InsertButtonProc(ctrlName) : ButtonControl
	String ctrlName
	
	//loop through the selected files in the list...
	Wave/T fileWave=$"root:FileList:fileWave"
	Wave sel=$"root:FileList:selWave"
	//and adjust the included file lists
	Wave/T includedFileWave=$"root:FileList:includedFileWave"
	Wave selToDel=$"root:FileList:selToDelWave"
	
	Variable numIncl=numpnts(includedFileWave)
	Variable num=numpnts(sel),ii,ok
	String fname=""

	//Necessary for every analysis experiment
	Execute/P "INSERTINCLUDE \"PlotUtilsMacro\""
	Execute/P "INSERTINCLUDE \"GaussUtils\""
	Execute/P "INSERTINCLUDE \"WriteModelData\""
	
	NVAR doCheck=root:FileList:checkForFiles
	
	ii=num-1		//work bottom-up to not lose the index
	do
		if(sel[ii] == 1)
			//can I make sure the file exists before trying to include it?
			if(doCheck)
				ok = CheckFileInUPFolder(fileWave[ii])
			endif
			if(ok || !doCheck)
				fname = RemoveExten(fileWave[ii])	
				Execute/P "INSERTINCLUDE \""+fname+"\""
				// add to the already included list, and remove from the to-include list (and selWaves also)
				InsertPoints numpnts(includedFileWave), 1, includedFileWave,selToDel
				includedFileWave[numpnts(includedFileWave)-1]=fileWave[ii]
				
				DeletePoints ii, 1, fileWave,sel
			else
				DoAlert 0,"File "+fileWave[ii]+" was not found in the User Procedures folder, so it was not included"
			endif
		endif
		ii-=1
	while(ii>=0)
	Execute/P "COMPILEPROCEDURES ";Execute/P/Q/Z "RefreshMenu()"
	
	sel=0		//clear the selections
	selToDel=0
	
	return(0)
End

Function FileList_RemoveButtonProc(ctrlName) : ButtonControl
	String ctrlName
	
	//loop through the selected files in the list...
	Wave/T includedFileWave=$"root:FileList:includedFileWave"
	Wave selToDel=$"root:FileList:selToDelWave"
	// and put the unwanted procedures back in the to-add list
	Wave/T fileWave=$"root:FileList:fileWave"
	Wave sel=$"root:FileList:selWave"
	
	
	Variable num=numpnts(selToDel),ii
	String fname=""
	
	ii=num-1		//work backwards
	do
		if(selToDel[ii] == 1)
			fname = RemoveExten(includedFileWave[ii])
			Execute/P "DELETEINCLUDE \""+fname+"\""
			//add to the to-include list
			InsertPoints numpnts(fileWave), 1, fileWave,sel
			fileWave[numpnts(fileWave)-1]=includedFileWave[ii]
			//delete the point 
			DeletePoints ii, 1, includedFileWave,selToDel
		endif
		ii-=1
	while(ii>=0)
	Execute/P "COMPILEPROCEDURES ";Execute/P/Q/Z "RefreshMenu()"
	
	sel=0
	selToDel=0
	
	Sort filewave,filewave
	return(0)
End


//removes ANY ".ext" extension from the name
// - wipes out all after the "dot"
// - procedure files to be included (using quotes) must be in User Procedures folder
// and end in .ipf?
Function/S RemoveExten(str)
	String str
	
	Variable loc=0
	String tempStr=""
	
	loc=strsearch(str,".",0)
	tempStr=str[0,loc-1]
	return(tempStr)
End

// function to have user select the path where the procedure files are
//	- the selected path is set as procPathName
//
// setting the path to "igor" does not seem to have the desired effect of 
// bringing up the Igor Pro folder in the NewPath Dialog
//
//may also be able to use folder lists on HD - for more sophisticated listings
Function PickProcPath()
	
	//set the global string to the selected pathname
	PathInfo/S Igor
	
	NewPath/O/M="pick the SANS Procedure folder" procPathName
	return(0)		//no error
End


//my menu, seemingly one item, but really a long string for each submenu
// if root:MenuItemStr exists
Menu "SANS Models"
	StrVarOrDefault("root:FileList:MenuItemStr_def","ModelPicker_Panel")//, RefreshMenu()
	SubMenu "Unsmeared Models"
		StrVarOrDefault("root:FileList:MenuItemStr1","ModelPicker_Panel")
	End
	SubMenu "Smeared Models"
		StrVarOrDefault("root:FileList:MenuItemStr2","ModelPicker_Panel")
	End
//	SubMenu "Models 3"
//		StrVarOrDefault("root:MenuItemStr3","ModelPicker_Panel")
//	End
End

//wrapper to use the A_ prepended file loader from the dynamically defined menu
Proc LoadSANSorUSANSData()
	A_LoadOneDData()
End

// tweaked to find RPA model which has an extra parameter in the declaration
Function RefreshMenu()

	String list="",sep=";"
	
	//list = "Refresh Menu"+sep+"ModelPicker_Panel"+sep+"-"+sep
	list = "ModelPicker_Panel"+sep+"-"+sep
//	list += MacroList("LoadO*",sep,"KIND:1,NPARAMS:0")		//data loader
	list += "Load SANS or USANS Data;"		//use the wrapper above to get the right loader
	list += "Reset Resolution Waves;"		// resets the resolution waves used for the calculations
	list += "Freeze Model;"						// freeze a model to compare plots on the same graph
	list += MacroList("WriteM*",sep,"KIND:1,NPARAMS:4")		//data writer
	list += "-"+sep
	String/G root:FileList:MenuItemStr_def = TrimListTo255(list)
	
	list = ""
	list += MacroList("*",sep,"KIND:1,NPARAMS:3")				//unsmeared plot procedures
	list += MacroList("Plot*",sep,"KIND:1,NPARAMS:4")				//RPA has 4 parameters
	list = RemoveFromList("FreezeModel", list ,";")			// remove FreezeModel, it's not a model
	//	list += "-"+sep
	String/G root:FileList:MenuItemStr1 = TrimListTo255(list)

	list=""
	list += MacroList("PlotSmea*",sep,"KIND:1,NPARAMS:0")			//smeared plot procedures
	list += MacroList("PlotSmea*",sep,"KIND:1,NPARAMS:1")			//smeared RPA has 1 parameter
	String/G root:FileList:MenuItemStr2 = TrimListTo255(list)

	BuildMenu "SANS Models"
	
	return(0)
End

//if the length of any of the strings is more than 255, the menu will disappear
Function/S TrimListTo255(list)
	String list
	
	Variable len,num
	num = itemsinlist(list,";")
	len = strlen(list)
	if(len>255)
		DoAlert 0, "Not all menu items are shown - remove some of the models"
		do
			list = RemoveListItem(num-1, list  ,";" )
			len=strlen(list)
			num=itemsinlist(list,";")
		while(len>255)
	endif
	return(list)
End

Function/S MP_TextWave2SemiList(textW)
	Wave/T textW
	
	String list=""
	Variable num=numpnts(textW),ii=0
	do
		list += textw[ii] + ";"
		ii+=1
	while(ii<num)
	return(list)
End

Function MP_SemiList2TextWave(list,outWStr)
	String list,outWStr
	
	Variable num=itemsinList(list)
	Make/T/O/N=(num) $outWStr
	WAVE/T w=$outWStr
	w = StringFromList(p,list,";")
	return(0)
End

//modified to get a list of all files in folder and subfolders
// passed back through a global variable
Function ListAllFilesAndFolders(pathName, full, recurse, level)
	String pathName		// Name of symbolic path in which to look for folders.
	Variable full			// True to print full paths instead of just folder name.
	Variable recurse		// True to recurse (do it for subfolders too).
	Variable level		// Recursion level. Pass 0 for the top level.
	
	Variable ii
	String prefix
	
	SVAR allFiles=root:FileList:allFiles
	// Build a prefix (a number of tabs to indicate the folder level by indentation)
	prefix = ""
	ii = 0
	do
		if (ii >= level)
			break
		endif
		prefix += "\t"					// Indent one more tab
		ii += 1
	while(1)
	
//	Printf "%s%s\r", prefix, pathName
//	Print IndexedFile($pathName,-1,"????")
	allFiles += IndexedFile($pathName,-1,"????")
	
	String path
	ii = 0
	do
		path = IndexedDir($pathName, ii, full)
		if (strlen(path) == 0)
			break							// No more folders
		endif
//		Printf "%s%s\r", prefix, path
		
		if (recurse)						// Do we want to go into subfolder?
			String subFolderPathName = "tempPrintFoldersPath_" + num2istr(level+1)
			
			// Now we get the path to the new parent folder
			String subFolderPath
			if (full)
				subFolderPath = path	// We already have the full path.
			else
				PathInfo $pathName		// We have only the folder name. Need to get full path.
				subFolderPath = S_path + path
			endif
			
			NewPath/Q/O $subFolderPathName, subFolderPath
			ListAllFilesAndFolders(subFolderPathName, full, recurse, level+1)
			KillPath/Z $subFolderPathName
		endif
		
		ii += 1
	while(1)
End


// utility function to get the list of all functions
// first - select and include all of the models
//
Proc GetAllModelFunctions()
	String str =  FunctionList("*",";","KIND:10,NINDVARS:1")
	Print itemsinList(str)

	MP_SemiList2TextWave(str,"UserFunctionList")
	edit UserFunctionList
end

// allows an easy way to "freeze" a model calculation
// - duplicates X and Y waves (tags them _q and _i)
// - kill the dependecy
// - append it to the top graph
// - it can later be exported with WriteModelData
//
// in Igor 5, you can restrict the WaveList to be just the top graph...
// SRK  09 JUN 2006
//
Proc FreezeModel(xWave,yWave,newNameStr)
	String xWave,yWave,newNameStr
	Prompt xwave,"X data",popup,WaveList("*",";","")
	Prompt ywave,"y data",popup,WaveList("*",";","")
	Prompt newNameStr,"new name for the waves, _q and _i will be appended"
	
	Duplicate/O $xwave,$(newNameStr+"_q")
	Duplicate/O $ywave,$(newNameStr+"_i")
	SetFormula $(newNameStr+"_i"), ""
	
	AppendToGraph $(newNameStr+"_i") vs $(newNameStr+"_q") 
	
End