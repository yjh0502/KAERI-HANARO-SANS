#pragma rtGlobals=1		// Use modern global access method.
//
// be sure to include all of the necessary files
//
#include "LogNormalSphere"

#include "HardSphereStruct"
#include "HPMSA"
#include "SquareWellStruct"
#include "StickyHardSphereStruct"

Proc PlotLogNormalSphere_HS(num,qmin,qmax)
	Variable num=128,qmin=0.001,qmax=0.7
	Prompt num "Enter number of data points for model: "
	Prompt qmin "Enter minimum q-value (A^-1) for model: "
	Prompt qmax "Enter maximum q-value (A^-1) for model: "
	
	Make/O/D/N=(num) xwave_lns_HS,ywave_lns_HS
	xwave_lns_HS = alog( log(qmin) + x*((log(qmax)-log(qmin))/num) )
	Make/O/D coef_lns_HS = {0.01,60,0.2,1e-6,3e-6,0.001}
	make/O/T parameters_lns_HS = {"Volume Fraction (scale)","mean radius (A)","polydisp (sig/avg)","SLD sphere (A-2)","SLD solvent (A-2)","bkg (cm-1 sr-1)"}
	Edit parameters_lns_HS,coef_lns_HS
	ywave_lns_HS := LogNormalSphere_HS(coef_lns_HS,xwave_lns_HS)
	Display ywave_lns_HS vs xwave_lns_HS
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
End

Proc PlotSmearedLogNormalSphere_HS()								
	//no input parameters necessary, it MUST use the experimental q-values
	// from the experimental data read in from an AVE/QSIG data file
	
	// if no gQvals wave, data must not have been loaded => abort
	if(ResolutionWavesMissing())
		Abort
	endif
	
	// Setup parameter table for model function
	Make/O/D smear_coef_lns_HS = {0.01,60,0.2,1e-6,3e-6,0.001}					
	make/o/t smear_parameters_lns_HS = {"Volume Fraction (scale)","mean radius (A)","polydisp (sig/avg)","SLD sphere (A-2)","SLD solvent (A-2)","bkg (cm-1 sr-1)"}	
	Edit smear_parameters_lns_HS,smear_coef_lns_HS					
	
	// output smeared intensity wave, dimensions are identical to experimental QSIG values
	// make extra copy of experimental q-values for easy plotting
	Duplicate/O $gQvals smeared_lns_HS,smeared_qvals				
	SetScale d,0,0,"1/cm",smeared_lns_HS							

	smeared_lns_HS := SmearedLogNormalSphere_HS(smear_coef_lns_HS,$gQvals)		
	Display smeared_lns_HS vs smeared_qvals									
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
End

Function LogNormalSphere_HS(w,x) : FitFunc
	Wave w
	Variable x
	
	Variable inten
	
	//setup form factor coefficient wave
	Make/O/D/N=6 form_lns_HS
	form_lns_HS[0] = 1
	form_lns_HS[1] = w[1]
	form_lns_HS[2] = w[2]
	form_lns_HS[3] = w[3]
	form_lns_HS[4] = w[4]
	form_lns_HS[5] = 0
	
	//calculate the diameter of the effective one-component sphere
	Variable r3,mu,sig,diam
	sig = w[2]		 		//polydispersity
	mu = ln(w[1])			//ln of mean radius
	r3 = exp(3*mu + 9/2*sig^2)		// <R^3> calculated directly for log-normal distr.
	
	diam = 2*(r3)^(1/3)
	
	
	//setup structure factor coefficient wave
	Make/O/D/N=2 struct_lns_HS
	struct_lns_HS[0] = diam/2
	struct_lns_HS[1] = w[0]
	
	//calculate each and combine
	inten = LogNormalPolySphere(form_lns_HS,x)
	inten *= HardSphereStruct(struct_lns_HS,x)
	inten *= w[0]
	inten += w[5]
	
	//cleanup waves
//	Killwaves/Z form_lns_HS,struct_lns_HS
	
	return (inten)
End

/////////////////////////////////////////
Proc PlotLogNormalSphere_SW(num,qmin,qmax)
	Variable num=128,qmin=0.001,qmax=0.7
	Prompt num "Enter number of data points for model: "
	Prompt qmin "Enter minimum q-value (A^-1) for model: "
	Prompt qmax "Enter maximum q-value (A^-1) for model: "
	
	Make/O/D/N=(num) xwave_lns_SW,ywave_lns_SW
	xwave_lns_SW = alog( log(qmin) + x*((log(qmax)-log(qmin))/num) )
	Make/O/D coef_lns_SW = {0.01,60,0.2,1e-6,3e-6,1.0,1.2,0.001}
	make/O/T parameters_lns_SW = {"Volume Fraction (scale)","mean radius (A)","polydisp (sig/avg)","SLD sphere (A-2)","SLD solvent (A-2)","well depth (kT)","well width (diam.)","bkg (cm-1 sr-1)"}
	Edit parameters_lns_SW,coef_lns_SW
	ywave_lns_SW := LogNormalSphere_SW(coef_lns_SW,xwave_lns_SW)
	Display ywave_lns_SW vs xwave_lns_SW
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
End

Proc PlotSmearedLogNormalSphere_SW()								
	//no input parameters necessary, it MUST use the experimental q-values
	// from the experimental data read in from an AVE/QSIG data file
	
	// if no gQvals wave, data must not have been loaded => abort
	if(ResolutionWavesMissing())
		Abort
	endif
	
	// Setup parameter table for model function
	Make/O/D smear_coef_lns_SW = {0.01,60,0.2,1e-6,3e-6,1.0,1.2,0.001}					
	make/o/t smear_parameters_lns_SW = {"Volume Fraction (scale)","mean radius (A)","polydisp (sig/avg)","SLD sphere (A-2)","SLD solvent (A-2)","well depth (kT)","well width (diam.)","bkg (cm-1 sr-1)"}	
	Edit smear_parameters_lns_SW,smear_coef_lns_SW					
	
	// output smeared intensity wave, dimensions are identical to experimental QSIG values
	// make extra copy of experimental q-values for easy plotting
	Duplicate/O $gQvals smeared_lns_SW,smeared_qvals				
	SetScale d,0,0,"1/cm",smeared_lns_SW							

	smeared_lns_SW := SmearedLogNormalSphere_SW(smear_coef_lns_SW,$gQvals)		
	Display smeared_lns_SW vs smeared_qvals									
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
End

Function LogNormalSphere_SW(w,x) : FitFunc
	Wave w
	Variable x
	
	Variable inten
	
	//setup form factor coefficient wave
	Make/O/D/N=6 form_lns_SW
	form_lns_SW[0] = 1
	form_lns_SW[1] = w[1]
	form_lns_SW[2] = w[2]
	form_lns_SW[3] = w[3]
	form_lns_SW[4] = w[4]
	form_lns_SW[5] = 0
	
	//calculate the diameter of the effective one-component sphere
	Variable r3,mu,sig,diam
	sig = w[2]		 		//polydispersity
	mu = ln(w[1])			//ln of mean radius
	r3 = exp(3*mu + 9/2*sig^2)		// <R^3> calculated directly for log-normal distr.
	
	diam = 2*(r3)^(1/3)
	
	//setup structure factor coefficient wave
	Make/O/D/N=4 struct_lns_SW
	struct_lns_SW[0] = diam/2
	struct_lns_SW[1] = w[0]
	struct_lns_SW[2] = w[5]
	struct_lns_SW[3] = w[6]
	
	//calculate each and combine
	inten = LogNormalPolySphere(form_lns_SW,x)
	inten *= SquareWellStruct(struct_lns_SW,x)
	inten *= w[0]
	inten += w[7]
	
	//cleanup waves
//	Killwaves/Z form_lns_SW,struct_lns_SW
	
	return (inten)
End


/////////////////////////////////////////
Proc PlotLogNormalSphere_SC(num,qmin,qmax)
	Variable num=256,qmin=0.001,qmax=0.7
	Prompt num "Enter number of data points for model: "
	Prompt qmin "Enter minimum q-value (A^-1) for model: "
	Prompt qmax "Enter maximum q-value (A^-1) for model: "
	
	if (DataFolderExists("root:HayPenMSA"))
 		Make/O/D/N=17 root:HayPenMSA:gMSAWave
 	else
 		NewDataFolder root:HayPenMSA
 		Make/O/D/N=17 root:HayPenMSA:gMSAWave
	endif

	Make/O/D/N=(num) xwave_lns_SC,ywave_lns_SC
	xwave_lns_SC = alog( log(qmin) + x*((log(qmax)-log(qmin))/num) )
	Make/O/D coef_lns_SC = {0.01,60,0.2,1e-6,3e-6,20,0,298,78,0.001}
	make/O/T parameters_lns_SC = {"Volume Fraction (scale)","mean radius (A)","polydisp (sig/avg)","SLD sphere (A-2)","SLD solvent (A-2)","charge","movalent salt(M)","Temperature (K)","dielectric const","bkg (cm-1 sr-1)"}
	Edit parameters_lns_SC,coef_lns_SC
	ywave_lns_SC := LogNormalSphere_SC(coef_lns_SC,xwave_lns_SC)
	Display ywave_lns_SC vs xwave_lns_SC
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
End

Proc PlotSmearedLogNormalSphere_SC()								
	//no input parameters necessary, it MUST use the experimental q-values
	// from the experimental data read in from an AVE/QSIG data file
	
	// if no gQvals wave, data must not have been loaded => abort
	if(ResolutionWavesMissing())
		Abort
	endif

	if (DataFolderExists("root:HayPenMSA"))
 		Make/O/D/N=17 root:HayPenMSA:gMSAWave
 	else
 		NewDataFolder root:HayPenMSA
 		Make/O/D/N=17 root:HayPenMSA:gMSAWave
	endif
	
	// Setup parameter table for model function
	Make/O/D smear_coef_lns_SC = {0.01,60,0.2,1e-6,3e-6,20,0,298,78,0.001}					
	make/o/t smear_parameters_lns_SC = {"Volume Fraction (scale)","mean radius (A)","polydisp (sig/avg)","SLD sphere (A-2)","SLD solvent (A-2)","charge","movalent salt(M)","Temperature (K)","dielectric const","bkg (cm-1 sr-1)"}	
	Edit smear_parameters_lns_SC,smear_coef_lns_SC					
	
	// output smeared intensity wave, dimensions are identical to experimental QSIG values
	// make extra copy of experimental q-values for easy plotting
	Duplicate/O $gQvals smeared_lns_SC,smeared_qvals				
	SetScale d,0,0,"1/cm",smeared_lns_SC							

	smeared_lns_SC := SmearedLogNormalSphere_SC(smear_coef_lns_SC,$gQvals)		
	Display smeared_lns_SC vs smeared_qvals									
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
End

Function LogNormalSphere_SC(w,x) : FitFunc
	Wave w
	Variable x
	
	Variable inten
	
	//setup form factor coefficient wave
	Make/O/D/N=6 form_lns_SC
	form_lns_SC[0] = 1
	form_lns_SC[1] = w[1]
	form_lns_SC[2] = w[2]
	form_lns_SC[3] = w[3]
	form_lns_SC[4] = w[4]
	form_lns_SC[5] = 0
	
	//calculate the diameter of the effective one-component sphere
	Variable r3,mu,sig,diam
	sig = w[2]		 		//polydispersity
	mu = ln(w[1])			//ln of mean radius
	r3 = exp(3*mu + 9/2*sig^2)		// <R^3> calculated directly for log-normal distr.
	
	diam = 2*(r3)^(1/3)
	
	//setup structure factor coefficient wave
	Make/O/D/N=6 struct_lns_SC
	struct_lns_SC[0] = diam
	struct_lns_SC[1] = w[5]
	struct_lns_SC[2] = w[0]
	struct_lns_SC[3] = w[7]
	struct_lns_SC[4] = w[6]
	struct_lns_SC[5] = w[8]
	
	//calculate each and combine
	inten = LogNormalPolySphere(form_lns_SC,x)
	inten *= HayterPenfoldMSA(struct_lns_SC,x)
	inten *= w[0]
	inten += w[9]
	
	//cleanup waves
//	Killwaves/Z form_lns_SC,struct_lns_SC
	
	return (inten)
End

/////////////////////////////////////////
Proc PlotLogNormalSphere_SHS(num,qmin,qmax)
	Variable num=256,qmin=0.001,qmax=0.7
	Prompt num "Enter number of data points for model: "
	Prompt qmin "Enter minimum q-value (A^-1) for model: "
	Prompt qmax "Enter maximum q-value (A^-1) for model: "
	
	Make/O/D/N=(num) xwave_lns_SHS,ywave_lns_SHS
	xwave_lns_SHS = alog( log(qmin) + x*((log(qmax)-log(qmin))/num) )
	Make/O/D coef_lns_SHS = {0.01,60,0.2,1e-6,3e-6,0.05,0.2,0.001}
	make/O/T parameters_lns_SHS = {"Volume Fraction (scale)","mean radius (A)","polydisp (sig/avg)","SLD sphere (A-2)","SLD solvent (A-2)","perturbation parameter (0.1)","stickiness, tau","bkg (cm-1 sr-1)"}
	Edit parameters_lns_SHS,coef_lns_SHS
	ywave_lns_SHS := LogNormalSphere_SHS(coef_lns_SHS,xwave_lns_SHS)
	Display ywave_lns_SHS vs xwave_lns_SHS
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
End

Proc PlotSmearedLogNormalSphere_SHS()								
	//no input parameters necessary, it MUST use the experimental q-values
	// from the experimental data read in from an AVE/QSIG data file
	
	// if no gQvals wave, data must not have been loaded => abort
	if(ResolutionWavesMissing())
		Abort
	endif
	
	// Setup parameter table for model function
	Make/O/D smear_coef_lns_SHS = {0.01,60,0.2,1e-6,3e-6,0.05,0.2,0.001}					
	make/o/t smear_parameters_lns_SHS = {"Volume Fraction (scale)","mean radius (A)","polydisp (sig/avg)","SLD sphere (A-2)","SLD solvent (A-2)","perturbation parameter (0.1)","stickiness, tau","bkg (cm-1 sr-1)"}	
	Edit smear_parameters_lns_SHS,smear_coef_lns_SHS					
	
	// output smeared intensity wave, dimensions are identical to experimental QSIG values
	// make extra copy of experimental q-values for easy plotting
	Duplicate/O $gQvals smeared_lns_SHS,smeared_qvals				
	SetScale d,0,0,"1/cm",smeared_lns_SHS							

	smeared_lns_SHS := SmearedLogNormalSphere_SHS(smear_coef_lns_SHS,$gQvals)		
	Display smeared_lns_SHS vs smeared_qvals									
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
End

Function LogNormalSphere_SHS(w,x) : FitFunc
	Wave w
	Variable x
	
	Variable inten
	
	//setup form factor coefficient wave
	Make/O/D/N=6 form_lns_SHS
	form_lns_SHS[0] = 1
	form_lns_SHS[1] = w[1]
	form_lns_SHS[2] = w[2]
	form_lns_SHS[3] = w[3]
	form_lns_SHS[4] = w[4]
	form_lns_SHS[5] = 0
	
	//calculate the diameter of the effective one-component sphere
	Variable r3,mu,sig,diam
	sig = w[2]		 		//polydispersity
	mu = ln(w[1])			//ln of mean radius
	r3 = exp(3*mu + 9/2*sig^2)		// <R^3> calculated directly for log-normal distr.
	
	diam = 2*(r3)^(1/3)
	
	//setup structure factor coefficient wave
	Make/O/D/N=4 struct_lns_SHS
	struct_lns_SHS[0] = diam/2
	struct_lns_SHS[1] = w[0]
	struct_lns_SHS[2] = w[5]
	struct_lns_SHS[3] = w[6]
	
	//calculate each and combine
	inten = LogNormalPolySphere(form_lns_SHS,x)
	inten *= StickyHS_Struct(struct_lns_SHS,x)
	inten *= w[0]
	inten += w[7]
	
	//cleanup waves
//	Killwaves/Z form_lns_SHS,struct_lns_SHS
	
	return (inten)
End


// this is all there is to the smeared calculation!
Function SmearedLogNormalSphere_HS(w,x) :FitFunc
	Wave w
	Variable x
	
	Variable ans
	SVAR sq = gSig_Q
	SVAR qb = gQ_bar
	SVAR sh = gShadow
	SVAR gQ = gQVals
	
	//the name of your unsmeared model is the first argument
	ans = Smear_Model_20(LogNormalSphere_HS,$sq,$qb,$sh,$gQ,w,x)

	return(ans)
End

// this is all there is to the smeared calculation!
Function SmearedLogNormalSphere_SW(w,x) :FitFunc
	Wave w
	Variable x
	
	Variable ans
	SVAR sq = gSig_Q
	SVAR qb = gQ_bar
	SVAR sh = gShadow
	SVAR gQ = gQVals
	
	//the name of your unsmeared model is the first argument
	ans = Smear_Model_20(LogNormalSphere_SW,$sq,$qb,$sh,$gQ,w,x)

	return(ans)
End

// this is all there is to the smeared calculation!
Function SmearedLogNormalSphere_SC(w,x) :FitFunc
	Wave w
	Variable x
	
	Variable ans
	SVAR sq = gSig_Q
	SVAR qb = gQ_bar
	SVAR sh = gShadow
	SVAR gQ = gQVals
	
	//the name of your unsmeared model is the first argument
	ans = Smear_Model_20(LogNormalSphere_SC,$sq,$qb,$sh,$gQ,w,x)

	return(ans)
End

// this is all there is to the smeared calculation!
Function SmearedLogNormalSphere_SHS(w,x) :FitFunc
	Wave w
	Variable x
	
	Variable ans
	SVAR sq = gSig_Q
	SVAR qb = gQ_bar
	SVAR sh = gShadow
	SVAR gQ = gQVals
	
	//the name of your unsmeared model is the first argument
	ans = Smear_Model_20(LogNormalSphere_SHS,$sq,$qb,$sh,$gQ,w,x)

	return(ans)
End