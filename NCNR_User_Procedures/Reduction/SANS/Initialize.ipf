#pragma rtGlobals=1		// Use modern global access method.
#pragma version=5.2
#pragma IgorVersion=6.1

//***********************
// 091901 Vers 1.2
//
// Initialization procedures that must be run before any analysis is started
// this is accomplished by placing:
//
// Initialize()
// #include "includes"
//
// in the built-in procedure window of the .pxt (template) experiment
// IGOR recognizes this, and executes Initialize() immediately after
// compiling all of the included procedures. This is all done as the blank
// template is opened
//
// Choosing initialize from the SANS menu will do the same, and no harm is done
// to the experiment by re- initializing. no data or folders are overwritten
//
//************************

//this is the main initualization procedure that must be the first thing
//done when opening a new Data reduction experiment
//
//sets up data folders, globals, protocols, and draws the main panel
Proc Initialize()

	Variable curVersion = 5.2
	Variable oldVersion = NumVarOrDefault("root:SANS_RED_VERSION",curVersion)
	
	//check for really old versions
	if(itemsinlist(WinList("Includes.ipf", ";","INCLUDE:6"),";") != 0)
		//must be opening a v4.2 or earlier template
		oldVersion = 4.2
	endif
	
	if(itemsinlist(WinList("Includes_v510.ipf", ";","INCLUDE:6"),";") != 0)
		oldVersion = 5.10
	endif
	if(itemsinlist(WinList("Includes_v500.ipf", ";","INCLUDE:6"),";") != 0)
		oldVersion = 5.00
	endif
	
	if(oldVersion == curVersion)
		//must just be a new startup with the current version
		Variable/G root:SANS_RED_VERSION=5.20
	endif
	
	if(oldVersion < curVersion)
		String str = 	"This experiment was created with version "+num2str(oldVersion)+" of the macros. I'll try to make this work, but please start new work with a current template"
		DoAlert 0,str
	endif
	
	InitFolders()
	InitFakeProtocols()
	InitGlobals()	
	InitFacilityGlobals()
	DoWindow/F Main_Panel
	If(V_flag == 0)
		//draw panel
		Main_Panel()
	Endif
	ResizeCmdWindow()
	
	//unload the NCNR_Package_Loader, if NCNR not defined
	UnloadNCNR_Igor_Procedures()

End

//creates all the necessary data folders in the root folder
//does not overwrite any existing folders of the same name
//it leaves data in them untouched
Function InitFolders()
	
	NewDataFolder/O root:Packages
	NewDataFolder/O root:Packages:NIST
	
	NewDataFolder/O root:myGlobals
	NewDataFolder/O root:myGlobals:CatVSHeaderInfo
	NewDataFolder/O root:Packages:NIST:RAW
	NewDataFolder/O root:Packages:NIST:SAM
	NewDataFolder/O root:Packages:NIST:EMP
	NewDataFolder/O root:Packages:NIST:BGD
	NewDataFolder/O root:Packages:NIST:COR
	NewDataFolder/O root:Packages:NIST:DIV
	NewDataFolder/O root:Packages:NIST:MSK
	NewDataFolder/O root:Packages:NIST:ABS
	NewDataFolder/O root:Packages:NIST:CAL
	NewDataFolder/O root:Packages:NIST:STO
	NewDataFolder/O root:Packages:NIST:SUB
	NewDataFolder/O root:Packages:NIST:DRK
	

	
	Return(0)
End

//Global folder already exists...
//adds appropriate globals to the newly created myGlobals folder
//return data folder to root: before leaving
//
// global parameters used for detector constants are facility specific
// and have been moved
//
Function InitGlobals()
	
	Variable/G root:myGlobals:gIsLogScale = 0
	String/G root:myGlobals:gDataDisplayType = "RAW"
	
	//check platform, so Angstrom can be drawn correctly
	
	if(cmpstr("Macintosh",IgorInfo(2)) == 0)
		String/G root:Packages:NIST:gAngstStr = num2char(-127)
		Variable/G root:myGlobals:gIsMac = 1
	else
		//either Windows or Windows NT
		String/G root:Packages:NIST:gAngstStr = num2char(-59)
		Variable/G root:myGlobals:gIsMac = 0
		//SetIgorOption to keep some PC's (graphics cards?) from smoothing the 2D image
		Execute "SetIgorOption WinDraw,forceCOLORONCOLOR=1"
	endif
	
	//global to set log scale as the default for display of RAW data
	//these can be set using the Misc->Preferences panel
	//initializes preferences. this includes XML y/n, and SANS Reduction items. 
	// if they already exist, they won't be overwritten
	Execute "Initialize_Preferences()"	

	


	//set flag if Demo Version is detected
	Variable/G root:myGlobals:isDemoVersion = isDemo()
	
	//set XML globals
	String/G root:Packages:NIST:gXMLLoader_Title = ""
	
	Return(0)
End

//creates the "base" protocols that should be available, after creating the data folder
//
//all protocols are kept in the root:myGlobals:Protocols folder, created here
//
Function InitFakeProtocols()
	
	//*****as of 0901, protocols are 8 points long, [6] is used for work.drk, [7] is unused 
	NewDataFolder/O root:myGlobals:Protocols
	Make/O/T $"root:myGlobals:Protocols:Base"={"none","none","ask","ask","none","AVTYPE=Circular;SAVE=Yes;NAME=Manual;PLOT=Yes","DRK=none,DRKMODE=0,",""}
	Make/O/T $"root:myGlobals:Protocols:DoAll"={"ask","ask","ask","ask","ask","AVTYPE=Circular;SAVE=Yes;NAME=Manual;PLOT=Yes","DRK=none,DRKMODE=0,",""}
	Make/O/T/N=8 $"root:myGlobals:Protocols:CreateNew"			//null wave
	//Initialize waves to store values in
	
	String/G root:myGlobals:Protocols:gProtoStr=""
	String/G root:myGlobals:Protocols:gNewStr=""
	String/G root:myGlobals:Protocols:gAvgInfoStr = "AVTYPE=Circular;SAVE=Yes;NAME=Auto;PLOT=Yes;"
	
	Return(0)
End

//simple function to resize the comand window to a nice size, no matter what the resolution
//need to test out on several different monitors and both platforms
//
// could easily be incorporated into the initialization routines to ensure that the 
// command window is always visible at startup of the macros. No need for a hook function
//
Function ResizeCmdWindow()

	String str=IgorInfo(0),rect="",platform=igorinfo(2)
	Variable depth,left,top,right,bottom,factor
	
	if(cmpstr(platform,"Macintosh")==0)
		factor=1
	else
		factor = 0.6		//fudge factor to get command window on-screen on Windows
	endif
	rect = StringByKey("SCREEN1", str  ,":",";")	
	sscanf rect,"DEPTH=%d,RECT=%d,%d,%d,%d",depth, left,top,right,bottom
	MoveWindow/C  (left+3)*factor,(bottom-150)*factor,(right-50)*factor,(bottom-10)*factor
End

// since the NCNR procedures can't be loaded concurrently with the other facility functions,
// unload this procedure file, and add this to the functions that run at initialization of the 
// experiment
Function UnloadNCNR_Igor_Procedures()

#if (exists("NCNR")==6)			//defined in the main #includes file.
	//do nothing if an NCNR reduction experiment
#else
	if(ItemsInList(WinList("NCNR_Package_Loader.ipf", ";","WIN:128")))
		Execute/P "CloseProc /NAME=\"NCNR_Package_Loader.ipf\""
		Execute/P "COMPILEPROCEDURES "
	endif
#endif

End

//returns 1 if demo version, 0 if full version
Function IsDemo()

	// create small offscreen graph
	Display/W=(3000,3000,3010,3010)
	DoWindow/C IsDemoGraph

	// try to save a PICT or bitmap of it to the clipboard
	SavePICT/Z  as "Clipboard"
	Variable isDemo= V_Flag != 0	// if error: must be demo
	DoWindow/K IsDemoGraph
	return isDemo
End