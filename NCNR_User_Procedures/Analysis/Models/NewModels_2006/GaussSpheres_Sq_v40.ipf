#pragma rtGlobals=1		// Use modern global access method.
#pragma IgorVersion=6.1

//
// be sure to include all of the necessary files
//
#include "GaussSpheres_v40"

#include "HardSphereStruct_v40"
#include "HPMSA_v40"
#include "SquareWellStruct_v40"
#include "StickyHardSphereStruct_v40"
#include "Two_Yukawa_v40"

Proc PlotGaussPolySphere_HS(num,qmin,qmax)
	Variable num=128,qmin=0.001,qmax=0.7
	Prompt num "Enter number of data points for model: "
	Prompt qmin "Enter minimum q-value (A^-1) for model: "
	Prompt qmax "Enter maximum q-value (A^-1) for model: "
	
	Make/O/D/N=(num) xwave_pgs_HS,ywave_pgs_HS
	xwave_pgs_HS = alog( log(qmin) + x*((log(qmax)-log(qmin))/num) )
	Make/O/D coef_pgs_HS = {0.01,60,0.2,1e-6,3e-6,0.001}
	make/O/T parameters_pgs_HS = {"Volume Fraction (scale)","mean radius (A)","polydisp (sig/avg)","SLD sphere (A-2)","SLD solvent (A-2)","bkg (cm-1 sr-1)"}
	Edit parameters_pgs_HS,coef_pgs_HS
	
	Variable/G root:g_pgs_HS
	g_pgs_HS := GaussPolySphere_HS(coef_pgs_HS,ywave_pgs_HS,xwave_pgs_HS)
	Display ywave_pgs_HS vs xwave_pgs_HS
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
	
	AddModelToStrings("GaussPolySphere_HS","coef_pgs_HS","parameters_pgs_HS","pgs_HS")
End

// - sets up a dependency to a wrapper, not the actual SmearedModelFunction
Proc PlotSmearedGaussPolySphere_HS(str)								
	String str
	Prompt str,"Pick the data folder containing the resolution you want",popup,getAList(4)
	
	// if any of the resolution waves are missing => abort
	if(ResolutionWavesMissingDF(str))		//updated to NOT use global strings (in GaussUtils)
		Abort
	endif
	
	SetDataFolder $("root:"+str)
	
	// Setup parameter table for model function
	Make/O/D smear_coef_pgs_HS = {0.01,60,0.2,1e-6,3e-6,0.001}					
	make/o/t smear_parameters_pgs_HS = {"Volume Fraction (scale)","mean radius (A)","polydisp (sig/avg)","SLD sphere (A-2)","SLD solvent (A-2)","bkg (cm-1 sr-1)"}	
	Edit smear_parameters_pgs_HS,smear_coef_pgs_HS					
	
	// output smeared intensity wave, dimensions are identical to experimental QSIG values
	// make extra copy of experimental q-values for easy plotting
	Duplicate/O $(str+"_q") smeared_pgs_HS,smeared_qvals				
	SetScale d,0,0,"1/cm",smeared_pgs_HS							
					
	Variable/G gs_pgs_HS=0
	gs_pgs_HS := fSmearedGaussPolySphere_HS(smear_coef_pgs_HS,smeared_pgs_HS,smeared_qvals)	//this wrapper fills the STRUCT
	
	Display smeared_pgs_HS vs smeared_qvals									
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
	
	SetDataFolder root:
	AddModelToStrings("SmearedGaussPolySphere_HS","smear_coef_pgs_HS","smear_parameters_pgs_HS","pgs_HS")
End



Function GaussPolySphere_HS(w,yw,xw) : FitFunc
	Wave w,yw,xw
	
	Variable inten
	
	//setup form factor coefficient wave
	Make/O/D/N=6 form_pgs_HS
	form_pgs_HS[0] = 1
	form_pgs_HS[1] = w[1]
	form_pgs_HS[2] = w[2]
	form_pgs_HS[3] = w[3]
	form_pgs_HS[4] = w[4]
	form_pgs_HS[5] = 0
	
	//calculate the diameter of the effective one-component sphere
	Variable pd,diam,Vpoly,Ravg
	pd = w[2]
	Ravg = w[1]
	
	Vpoly = (4*pi/3*Ravg^3)*(1+3*pd^2)
	diam = (6*Vpoly/pi)^(1/3)
	
	
	//setup structure factor coefficient wave
	Make/O/D/N=2 struct_pgs_HS
	struct_pgs_HS[0] = diam/2
	struct_pgs_HS[1] = w[0]
	
	//calculate each and combine
	Duplicate/O xw tmp_pgs_HS_PQ,tmp_pgs_HS_SQ
	GaussSpheres(form_pgs_HS,tmp_pgs_HS_PQ,xw)
	HardSphereStruct(struct_pgs_HS,tmp_pgs_HS_SQ,xw)
	yw = tmp_pgs_HS_PQ * tmp_pgs_HS_SQ
	yw *= w[0]
	yw += w[5]
	
	//cleanup waves
//	Killwaves/Z form_pgs_HS,struct_pgs_HS
	
	return (0)
End

/////////////////////////////////////////
Proc PlotGaussPolySphere_SW(num,qmin,qmax)
	Variable num=128,qmin=0.001,qmax=0.7
	Prompt num "Enter number of data points for model: "
	Prompt qmin "Enter minimum q-value (A^-1) for model: "
	Prompt qmax "Enter maximum q-value (A^-1) for model: "
	
	Make/O/D/N=(num) xwave_pgs_SW,ywave_pgs_SW
	xwave_pgs_SW = alog( log(qmin) + x*((log(qmax)-log(qmin))/num) )
	Make/O/D coef_pgs_SW = {0.01,60,0.2,1e-6,3e-6,1.0,1.2,0.001}
	make/O/T parameters_pgs_SW = {"Volume Fraction (scale)","mean radius (A)","polydisp (sig/avg)","SLD sphere (A-2)","SLD solvent (A-2)","well depth (kT)","well width (diam.)","bkg (cm-1 sr-1)"}
	Edit parameters_pgs_SW,coef_pgs_SW
	
	Variable/G root:g_pgs_SW
	g_pgs_SW := GaussPolySphere_SW(coef_pgs_SW,ywave_pgs_SW,xwave_pgs_SW)
	Display ywave_pgs_SW vs xwave_pgs_SW
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
	
	AddModelToStrings("GaussPolySphere_SW","coef_pgs_SW","parameters_pgs_SW","pgs_SW")
End

// - sets up a dependency to a wrapper, not the actual SmearedModelFunction
Proc PlotSmearedGaussPolySphere_SW(str)								
	String str
	Prompt str,"Pick the data folder containing the resolution you want",popup,getAList(4)
	
	// if any of the resolution waves are missing => abort
	if(ResolutionWavesMissingDF(str))		//updated to NOT use global strings (in GaussUtils)
		Abort
	endif
	
	SetDataFolder $("root:"+str)
	
	// Setup parameter table for model function
	Make/O/D smear_coef_pgs_SW = {0.01,60,0.2,1e-6,3e-6,1.0,1.2,0.001}					
	make/o/t smear_parameters_pgs_SW = {"Volume Fraction (scale)","mean radius (A)","polydisp (sig/avg)","SLD sphere (A-2)","SLD solvent (A-2)","well depth (kT)","well width (diam.)","bkg (cm-1 sr-1)"}	
	Edit smear_parameters_pgs_SW,smear_coef_pgs_SW					
	
	// output smeared intensity wave, dimensions are identical to experimental QSIG values
	// make extra copy of experimental q-values for easy plotting
	Duplicate/O $(str+"_q") smeared_pgs_SW,smeared_qvals				
	SetScale d,0,0,"1/cm",smeared_pgs_SW							
					
	Variable/G gs_pgs_SW=0
	gs_pgs_SW := fSmearedGaussPolySphere_SW(smear_coef_pgs_SW,smeared_pgs_SW,smeared_qvals)	//this wrapper fills the STRUCT
	
	Display smeared_pgs_SW vs smeared_qvals									
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
	
	SetDataFolder root:
	AddModelToStrings("SmearedGaussPolySphere_SW","smear_coef_pgs_SW","smear_parameters_pgs_SW","pgs_SW")
End
	

Function GaussPolySphere_SW(w,yw,xw) : FitFunc
	Wave w,yw,xw
	
	Variable inten
	
	//setup form factor coefficient wave
	Make/O/D/N=6 form_pgs_SW
	form_pgs_SW[0] = 1
	form_pgs_SW[1] = w[1]
	form_pgs_SW[2] = w[2]
	form_pgs_SW[3] = w[3]
	form_pgs_SW[4] = w[4]
	form_pgs_SW[5] = 0
	
	//calculate the diameter of the effective one-component sphere
	Variable pd,diam,Vpoly,Ravg
	pd = w[2]
	Ravg = w[1]
	
	Vpoly = (4*pi/3*Ravg^3)*(1+3*pd^2)
	diam = (6*Vpoly/pi)^(1/3)
	
	//setup structure factor coefficient wave
	Make/O/D/N=4 struct_pgs_SW
	struct_pgs_SW[0] = diam/2
	struct_pgs_SW[1] = w[0]
	struct_pgs_SW[2] = w[5]
	struct_pgs_SW[3] = w[6]
	
	//calculate each and combine
	Duplicate/O xw tmp_pgs_SW_PQ,tmp_pgs_SW_SQ
	GaussSpheres(form_pgs_SW,tmp_pgs_SW_PQ,xw)
	SquareWellStruct(struct_pgs_SW,tmp_pgs_SW_SQ,xw)
	yw = tmp_pgs_SW_PQ * tmp_pgs_SW_SQ
	yw *= w[0]
	yw += w[7]
	
	//cleanup waves
//	Killwaves/Z form_pgs_SW,struct_pgs_SW
	
	return (0)
End


/////////////////////////////////////////
Proc PlotGaussPolySphere_SC(num,qmin,qmax)
	Variable num=256,qmin=0.001,qmax=0.7
	Prompt num "Enter number of data points for model: "
	Prompt qmin "Enter minimum q-value (A^-1) for model: "
	Prompt qmax "Enter maximum q-value (A^-1) for model: "
	
	if(!DataFolderExists(":HayPenMSA"))
		NewDataFolder :HayPenMSA
	endif
 	Make/O/D/N=17 :HayPenMSA:gMSAWave

	Make/O/D/N=(num) xwave_pgs_SC,ywave_pgs_SC
	xwave_pgs_SC = alog( log(qmin) + x*((log(qmax)-log(qmin))/num) )
	Make/O/D coef_pgs_SC = {0.01,60,0.2,1e-6,3e-6,20,0,298,78,0.001}
	make/O/T parameters_pgs_SC = {"Volume Fraction (scale)","mean radius (A)","polydisp (sig/avg)","SLD sphere (A-2)","SLD solvent (A-2)","charge","movalent salt(M)","Temperature (K)","dielectric const","bkg (cm-1 sr-1)"}
	Edit parameters_pgs_SC,coef_pgs_SC
	
	Variable/G root:g_pgs_SC
	g_pgs_SC := GaussPolySphere_SC(coef_pgs_SC,ywave_pgs_SC,xwave_pgs_SC)
	Display ywave_pgs_SC vs xwave_pgs_SC
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
	
	AddModelToStrings("GaussPolySphere_SC","coef_pgs_SC","parameters_pgs_SC","pgs_SC")
End

// - sets up a dependency to a wrapper, not the actual SmearedModelFunction
Proc PlotSmearedGaussPolySphere_SC(str)								
	String str
	Prompt str,"Pick the data folder containing the resolution you want",popup,getAList(4)
	
	// if any of the resolution waves are missing => abort
	if(ResolutionWavesMissingDF(str))		//updated to NOT use global strings (in GaussUtils)
		Abort
	endif
	
	SetDataFolder $("root:"+str)
	
	if(!DataFolderExists(":HayPenMSA"))
		NewDataFolder :HayPenMSA
	endif
 	Make/O/D/N=17 :HayPenMSA:gMSAWave
	
	// Setup parameter table for model function
	Make/O/D smear_coef_pgs_SC = {0.01,60,0.2,1e-6,3e-6,20,0,298,78,0.001}					
	make/o/t smear_parameters_pgs_SC = {"Volume Fraction (scale)","mean radius (A)","polydisp (sig/avg)","SLD sphere (A-2)","SLD solvent (A-2)","charge","movalent salt(M)","Temperature (K)","dielectric const","bkg (cm-1 sr-1)"}	
	Edit smear_parameters_pgs_SC,smear_coef_pgs_SC					
	
	// output smeared intensity wave, dimensions are identical to experimental QSIG values
	// make extra copy of experimental q-values for easy plotting
	Duplicate/O $(str+"_q") smeared_pgs_SC,smeared_qvals				
	SetScale d,0,0,"1/cm",smeared_pgs_SC							
					
	Variable/G gs_pgs_SC=0
	gs_pgs_SC := fSmearedGaussPolySphere_SC(smear_coef_pgs_SC,smeared_pgs_SC,smeared_qvals)	//this wrapper fills the STRUCT
	
	Display smeared_pgs_SC vs smeared_qvals									
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
	
	SetDataFolder root:
	AddModelToStrings("SmearedGaussPolySphere_SC","smear_coef_pgs_SC","smear_parameters_pgs_SC","pgs_SC")
End


Function GaussPolySphere_SC(w,yw,xw) : FitFunc
	Wave w,yw,xw
	
	Variable inten
	
	//setup form factor coefficient wave
	Make/O/D/N=6 form_pgs_SC
	form_pgs_SC[0] = 1
	form_pgs_SC[1] = w[1]
	form_pgs_SC[2] = w[2]
	form_pgs_SC[3] = w[3]
	form_pgs_SC[4] = w[4]
	form_pgs_SC[5] = 0
	
	//calculate the diameter of the effective one-component sphere
	Variable pd,diam,Vpoly,Ravg
	pd = w[2]
	Ravg = w[1]
	
	Vpoly = (4*pi/3*Ravg^3)*(1+3*pd^2)
	diam = (6*Vpoly/pi)^(1/3)
	
	//setup structure factor coefficient wave
	Make/O/D/N=6 struct_pgs_SC
	struct_pgs_SC[0] = diam
	struct_pgs_SC[1] = w[5]
	struct_pgs_SC[2] = w[0]
	struct_pgs_SC[3] = w[7]
	struct_pgs_SC[4] = w[6]
	struct_pgs_SC[5] = w[8]
	
	//calculate each and combine
	Duplicate/O xw tmp_pgs_SC_PQ,tmp_pgs_SC_SQ
	GaussSpheres(form_pgs_SC,tmp_pgs_SC_PQ,xw)
	HayterPenfoldMSA(struct_pgs_SC,tmp_pgs_SC_SQ,xw)
	yw = tmp_pgs_SC_PQ * tmp_pgs_SC_SQ
	yw *= w[0]
	yw += w[9]
	
	//cleanup waves
//	Killwaves/Z form_pgs_SC,struct_pgs_SC
	
	return (0)
End

/////////////////////////////////////////
Proc PlotGaussPolySphere_SHS(num,qmin,qmax)
	Variable num=256,qmin=0.001,qmax=0.7
	Prompt num "Enter number of data points for model: "
	Prompt qmin "Enter minimum q-value (A^-1) for model: "
	Prompt qmax "Enter maximum q-value (A^-1) for model: "
	
	Make/O/D/N=(num) xwave_pgs_SHS,ywave_pgs_SHS
	xwave_pgs_SHS = alog( log(qmin) + x*((log(qmax)-log(qmin))/num) )
	Make/O/D coef_pgs_SHS = {0.01,60,0.2,1e-6,3e-6,0.05,0.2,0.001}
	make/O/T parameters_pgs_SHS = {"Volume Fraction (scale)","mean radius (A)","polydisp (sig/avg)","SLD sphere (A-2)","SLD solvent (A-2)","perturbation parameter (0.1)","stickiness, tau","bkg (cm-1 sr-1)"}
	Edit parameters_pgs_SHS,coef_pgs_SHS
	
	Variable/G root:g_pgs_SHS
	g_pgs_SHS := GaussPolySphere_SHS(coef_pgs_SHS,ywave_pgs_SHS,xwave_pgs_SHS)
	Display ywave_pgs_SHS vs xwave_pgs_SHS
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
	
	AddModelToStrings("GaussPolySphere_SHS","coef_pgs_SHS","parameters_pgs_SHS","pgs_SHS")
End

// - sets up a dependency to a wrapper, not the actual SmearedModelFunction
Proc PlotSmearedGaussPolySphere_SHS(str)								
	String str
	Prompt str,"Pick the data folder containing the resolution you want",popup,getAList(4)
	
	// if any of the resolution waves are missing => abort
	if(ResolutionWavesMissingDF(str))		//updated to NOT use global strings (in GaussUtils)
		Abort
	endif
	
	SetDataFolder $("root:"+str)
	
	// Setup parameter table for model function
	Make/O/D smear_coef_pgs_SHS = {0.01,60,0.2,1e-6,3e-6,0.05,0.2,0.001}					
	make/o/t smear_parameters_pgs_SHS = {"Volume Fraction (scale)","mean radius (A)","polydisp (sig/avg)","SLD sphere (A-2)","SLD solvent (A-2)","perturbation parameter (0.1)","stickiness, tau","bkg (cm-1 sr-1)"}	
	Edit smear_parameters_pgs_SHS,smear_coef_pgs_SHS					
	
	// output smeared intensity wave, dimensions are identical to experimental QSIG values
	// make extra copy of experimental q-values for easy plotting
	Duplicate/O $(str+"_q") smeared_pgs_SHS,smeared_qvals				
	SetScale d,0,0,"1/cm",smeared_pgs_SHS							
					
	Variable/G gs_pgs_SHS=0
	gs_pgs_SHS := fSmearedGaussPolySphere_SHS(smear_coef_pgs_SHS,smeared_pgs_SHS,smeared_qvals)	//this wrapper fills the STRUCT
	
	Display smeared_pgs_SHS vs smeared_qvals									
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
	
	SetDataFolder root:
	AddModelToStrings("SmearedGaussPolySphere_SHS","smear_coef_pgs_SHS","smear_parameters_pgs_SHS","pgs_SHS")
End
	

Function GaussPolySphere_SHS(w,yw,xw) : FitFunc
	Wave w,yw,xw
	
	Variable inten
	
	//setup form factor coefficient wave
	Make/O/D/N=6 form_pgs_SHS
	form_pgs_SHS[0] = 1
	form_pgs_SHS[1] = w[1]
	form_pgs_SHS[2] = w[2]
	form_pgs_SHS[3] = w[3]
	form_pgs_SHS[4] = w[4]
	form_pgs_SHS[5] = 0
	
	//calculate the diameter of the effective one-component sphere
	Variable pd,diam,Vpoly,Ravg
	pd = w[2]
	Ravg = w[1]
	
	Vpoly = (4*pi/3*Ravg^3)*(1+3*pd^2)
	diam = (6*Vpoly/pi)^(1/3)
	
	//setup structure factor coefficient wave
	Make/O/D/N=4 struct_pgs_SHS
	struct_pgs_SHS[0] = diam/2
	struct_pgs_SHS[1] = w[0]
	struct_pgs_SHS[2] = w[5]
	struct_pgs_SHS[3] = w[6]
	
	//calculate each and combine
	Duplicate/O xw tmp_pgs_SHS_PQ,tmp_pgs_SHS_SQ
	GaussSpheres(form_pgs_SHS,tmp_pgs_SHS_PQ,xw)
	StickyHS_Struct(struct_pgs_SHS,tmp_pgs_SHS_SQ,xw)
	yw = tmp_pgs_SHS_PQ * tmp_pgs_SHS_SQ
	yw *= w[0]
	yw += w[7]
	
	//cleanup waves
//	Killwaves/Z form_pgs_SHS,struct_pgs_SHS
	
	return (0)
End

//two yukawa
Proc PlotGaussPolySphere_2Y(num,qmin,qmax)
	Variable num=128,qmin=0.001,qmax=0.7
	Prompt num "Enter number of data points for model: "
	Prompt qmin "Enter minimum q-value (A^-1) for model: "
	Prompt qmax "Enter maximum q-value (A^-1) for model: "
	
	Make/O/D/N=(num) xwave_pgs_2Y,ywave_pgs_2Y
	xwave_pgs_2Y = alog( log(qmin) + x*((log(qmax)-log(qmin))/num) )
	Make/O/D coef_pgs_2Y = {0.01,60,0.2,1e-6,3e-6,6,10,-1,2,0.001}
	make/O/T parameters_pgs_2Y = {"Volume Fraction (scale)","mean radius (A)","polydisp (sig/avg)","SLD sphere (A-2)","SLD solvent (A-2)","scale, K1","charge, Z1","scale, K2","charge, Z2","bkg (cm-1 sr-1)"}
	Edit parameters_pgs_2Y,coef_pgs_2Y
	
	Variable/G root:g_pgs_2Y
	g_pgs_2Y := GaussPolySphere_2Y(coef_pgs_2Y,ywave_pgs_2Y,xwave_pgs_2Y)
	Display ywave_pgs_2Y vs xwave_pgs_2Y
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
	
	AddModelToStrings("GaussPolySphere_2Y","coef_pgs_2Y","parameters_pgs_2Y","pgs_2Y")
End

// - sets up a dependency to a wrapper, not the actual SmearedModelFunction
Proc PlotSmearedGaussPolySphere_2Y(str)								
	String str
	Prompt str,"Pick the data folder containing the resolution you want",popup,getAList(4)
	
	// if any of the resolution waves are missing => abort
	if(ResolutionWavesMissingDF(str))		//updated to NOT use global strings (in GaussUtils)
		Abort
	endif
	
	SetDataFolder $("root:"+str)
	
	// Setup parameter table for model function
	Make/O/D smear_coef_pgs_2Y = {0.01,60,0.2,1e-6,3e-6,6,10,-1,2,0.001}					
	make/o/t smear_parameters_pgs_2Y = {"Volume Fraction (scale)","mean radius (A)","polydisp (sig/avg)","SLD sphere (A-2)","SLD solvent (A-2)","scale, K1","charge, Z1","scale, K2","charge, Z2","bkg (cm-1 sr-1)"}	
	Edit smear_parameters_pgs_2Y,smear_coef_pgs_2Y					
	
	// output smeared intensity wave, dimensions are identical to experimental QSIG values
	// make extra copy of experimental q-values for easy plotting
	Duplicate/O $(str+"_q") smeared_pgs_2Y,smeared_qvals				
	SetScale d,0,0,"1/cm",smeared_pgs_2Y							
					
	Variable/G gs_pgs_2Y=0
	gs_pgs_2Y := fSmearedGaussPolySphere_2Y(smear_coef_pgs_2Y,smeared_pgs_2Y,smeared_qvals)	//this wrapper fills the STRUCT
	
	Display smeared_pgs_2Y vs smeared_qvals									
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
	
	SetDataFolder root:
	AddModelToStrings("SmearedGaussPolySphere_2Y","smear_coef_pgs_2Y","smear_parameters_pgs_2Y","pgs_2Y")
End



Function GaussPolySphere_2Y(w,yw,xw) : FitFunc
	Wave w,yw,xw
	
	Variable inten
	
	//setup form factor coefficient wave
	Make/O/D/N=6 form_pgs_2Y
	form_pgs_2Y[0] = 1
	form_pgs_2Y[1] = w[1]
	form_pgs_2Y[2] = w[2]
	form_pgs_2Y[3] = w[3]
	form_pgs_2Y[4] = w[4]
	form_pgs_2Y[5] = 0
	
	//calculate the diameter of the effective one-component sphere
	Variable pd,diam,Vpoly,Ravg
	pd = w[2]
	Ravg = w[1]
	
	Vpoly = (4*pi/3*Ravg^3)*(1+3*pd^2)
	diam = (6*Vpoly/pi)^(1/3)
	
	
	//setup structure factor coefficient wave
	Make/O/D/N=6 struct_pgs_2Y
	struct_pgs_2Y[0] = w[0]
	struct_pgs_2Y[1] = diam/2
	struct_pgs_2Y[2] = w[5]
	struct_pgs_2Y[3] = w[6]
	struct_pgs_2Y[4] = w[7]
	struct_pgs_2Y[5] = w[8]
	
	//calculate each and combine
	Duplicate/O xw tmp_pgs_2Y_PQ,tmp_pgs_2Y_SQ
	GaussSpheres(form_pgs_2Y,tmp_pgs_2Y_PQ,xw)
	TwoYukawa(struct_pgs_2Y,tmp_pgs_2Y_SQ,xw)
	yw = tmp_pgs_2Y_PQ * tmp_pgs_2Y_SQ
	yw *= w[0]
	yw += w[9]
	
	//cleanup waves
//	Killwaves/Z form_pgs_2Y,struct_pgs_2Y
	
	return (0)
End

// this is all there is to the smeared calculation!
Function SmearedGaussPolySphere_HS(s) : FitFunc
	Struct ResSmearAAOStruct &s

//	the name of your unsmeared model (AAO) is the first argument
	Smear_Model_20(GaussPolySphere_HS,s.coefW,s.xW,s.yW,s.resW)

	return(0)
End

// this is all there is to the smeared calculation!
Function SmearedGaussPolySphere_SW(s) : FitFunc
	Struct ResSmearAAOStruct &s

//	the name of your unsmeared model (AAO) is the first argument
	Smear_Model_20(GaussPolySphere_SW,s.coefW,s.xW,s.yW,s.resW)

	return(0)
End

// this is all there is to the smeared calculation!
Function SmearedGaussPolySphere_SC(s) : FitFunc
	Struct ResSmearAAOStruct &s

//	the name of your unsmeared model (AAO) is the first argument
	Smear_Model_20(GaussPolySphere_SC,s.coefW,s.xW,s.yW,s.resW)

	return(0)
End

// this is all there is to the smeared calculation!
Function SmearedGaussPolySphere_SHS(s) : FitFunc
	Struct ResSmearAAOStruct &s

//	the name of your unsmeared model (AAO) is the first argument
	Smear_Model_20(GaussPolySphere_SHS,s.coefW,s.xW,s.yW,s.resW)

	return(0)
End

// this is all there is to the smeared calculation!
Function SmearedGaussPolySphere_2Y(s) : FitFunc
	Struct ResSmearAAOStruct &s

//	the name of your unsmeared model (AAO) is the first argument
	Smear_Model_20(GaussPolySphere_2Y,s.coefW,s.xW,s.yW,s.resW)

	return(0)
End

//wrapper to calculate the smeared model as an AAO-Struct
// fills the struct and calls the ususal function with the STRUCT parameter
//
// used only for the dependency, not for fitting
//
Function fSmearedGaussPolySphere_HS(coefW,yW,xW)
	Wave coefW,yW,xW
	
	String str = getWavesDataFolder(yW,0)
	String DF="root:"+str+":"
	
	WAVE resW = $(DF+str+"_res")
	
	STRUCT ResSmearAAOStruct fs
	WAVE fs.coefW = coefW	
	WAVE fs.yW = yW
	WAVE fs.xW = xW
	WAVE fs.resW = resW
	
	Variable err
	err = SmearedGaussPolySphere_HS(fs)
	
	return (0)
End

//wrapper to calculate the smeared model as an AAO-Struct
// fills the struct and calls the ususal function with the STRUCT parameter
//
// used only for the dependency, not for fitting
//
Function fSmearedGaussPolySphere_SW(coefW,yW,xW)
	Wave coefW,yW,xW
	
	String str = getWavesDataFolder(yW,0)
	String DF="root:"+str+":"
	
	WAVE resW = $(DF+str+"_res")
	
	STRUCT ResSmearAAOStruct fs
	WAVE fs.coefW = coefW	
	WAVE fs.yW = yW
	WAVE fs.xW = xW
	WAVE fs.resW = resW
	
	Variable err
	err = SmearedGaussPolySphere_SW(fs)
	
	return (0)
End

//wrapper to calculate the smeared model as an AAO-Struct
// fills the struct and calls the ususal function with the STRUCT parameter
//
// used only for the dependency, not for fitting
//
Function fSmearedGaussPolySphere_SC(coefW,yW,xW)
	Wave coefW,yW,xW
	
	String str = getWavesDataFolder(yW,0)
	String DF="root:"+str+":"
	
	WAVE resW = $(DF+str+"_res")
	
	STRUCT ResSmearAAOStruct fs
	WAVE fs.coefW = coefW	
	WAVE fs.yW = yW
	WAVE fs.xW = xW
	WAVE fs.resW = resW
	
	Variable err
	err = SmearedGaussPolySphere_SC(fs)
	
	return (0)
End

//wrapper to calculate the smeared model as an AAO-Struct
// fills the struct and calls the ususal function with the STRUCT parameter
//
// used only for the dependency, not for fitting
//
Function fSmearedGaussPolySphere_SHS(coefW,yW,xW)
	Wave coefW,yW,xW
	
	String str = getWavesDataFolder(yW,0)
	String DF="root:"+str+":"
	
	WAVE resW = $(DF+str+"_res")
	
	STRUCT ResSmearAAOStruct fs
	WAVE fs.coefW = coefW	
	WAVE fs.yW = yW
	WAVE fs.xW = xW
	WAVE fs.resW = resW
	
	Variable err
	err = SmearedGaussPolySphere_SHS(fs)
	
	return (0)
End

//wrapper to calculate the smeared model as an AAO-Struct
// fills the struct and calls the ususal function with the STRUCT parameter
//
// used only for the dependency, not for fitting
//
Function fSmearedGaussPolySphere_2Y(coefW,yW,xW)
	Wave coefW,yW,xW
	
	String str = getWavesDataFolder(yW,0)
	String DF="root:"+str+":"
	
	WAVE resW = $(DF+str+"_res")
	
	STRUCT ResSmearAAOStruct fs
	WAVE fs.coefW = coefW	
	WAVE fs.yW = yW
	WAVE fs.xW = xW
	WAVE fs.resW = resW
	
	Variable err
	err = SmearedGaussPolySphere_2Y(fs)
	
	return (0)
End