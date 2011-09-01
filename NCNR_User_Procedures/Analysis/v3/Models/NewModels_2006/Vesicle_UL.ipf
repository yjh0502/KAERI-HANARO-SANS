#pragma rtGlobals=1		// Use modern global access method.

////////////////////////////////////////////////
// GaussUtils.proc and PlotUtils.proc MUST be included for the smearing calculation to compile
// Adopting these into the experiment will insure that they are always present
////////////////////////////////////////////////
//
// this function is for the form factor of a unilamellar vesicle
//
// the "scale" or "volume fraction" factor is the "material" volume fraction
// - i.e. the volume fraction of surfactant added. NOT the excluded volume
// of the vesicles, which can be much larger. See the Vesicle_Volume_N_Rg macro
//
// this excluded volume is accounted for in the structure factor calculations.
//
// a macro is also provided to calculate the number density, I(q=0)
// the Rg, and all of the volumes of the particle.
//
// 13 JUL 04 SRK
////////////////////////////////////////////////

Proc PlotVesicle(num,qmin,qmax)
	Variable num=128,qmin=0.001,qmax=0.7
	Prompt num "Enter number of data points for model: "
	Prompt qmin "Enter minimum q-value (A^-1) for model: "
	Prompt qmax "Enter maximum q-value (A^-1) for model: "
	
	make/o/d/n=(num) xwave_vesicle,ywave_vesicle
	xwave_vesicle =alog(log(qmin) + x*((log(qmax)-log(qmin))/num))
	make/o/d coef_vesicle = {1.,100,30,6.36e-6,0.5e-6,0}
	make/o/t parameters_vesicle = {"scale","core radius (A)","shell thickness (A)","Core and Solvent SLD (A-2)","Shell SLD (A-2)","bkg (cm-1)"}
	Edit parameters_vesicle,coef_vesicle
	ywave_vesicle := VesicleForm(coef_vesicle,xwave_vesicle)
	Display ywave_vesicle vs xwave_vesicle
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
End

///////////////////////////////////////////////////////////

Proc PlotSmearedVesicle()								//**** name of your function
	//no input parameters necessary, it MUST use the experimental q-values
	// from the experimental data read in from an AVE/QSIG data file
	
	// if no gQvals wave, data must not have been loaded => abort
	if(Exists("gQvals") != 2)		// 2 = string or numeric variable exists
		Abort "6-column QSIG data not loaded. Use LoadQSIGData macro"
	else
		if(WaveExists($gQvals) ==0)	//wave ref does not exist
			Abort "6-column QSIG waves are missing. Re-load with LoadQSIGData macro"
		endif
	endif
	
	// Setup parameter table for model function
	make/o/d smear_coef_vesicle = {1.,100,30,6.36e-6,0.5e-6,0}
	make/o/t smear_parameters_vesicle = {"scale","core radius (A)","shell thickness (A)","Core and Solvent SLD (A-2)","Shell SLD (A-2)","bkg (cm-1)"}
	Edit smear_parameters_vesicle,smear_coef_vesicle
	
	// output smeared intensity wave, dimensions are identical to experimental QSIG values
	// make extra copy of experimental q-values for easy plotting
	
	Duplicate/O $gQvals smeared_vesicle,smeared_qvals				
	SetScale d,0,0,"1/cm",smeared_vesicle							

	smeared_vesicle := SmearedVesicleForm(smear_coef_vesicle,$gQvals)
	Display smeared_vesicle vs smeared_qvals									
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
End

///////////////////////////////////////////////////////////////
// unsmeared model calculation
///////////////////////////
Function VesicleForm(w,x) : FitFunc
	Wave w
	Variable x
	
	// variables are:
	//[0] scale factor
	//[1] radius of core [A]
	//[2] thickness of the shell	[A]
	//[3] SLD of the core and solvent[A-2]
	//[4] SLD of the shell
	//[5] background	[cm-1]
	
	// All inputs are in ANGSTROMS
	//OUTPUT is normalized by the particle volume, and converted to [cm-1]
	
	
	Variable scale,rcore,thick,rhocore,rhoshel,rhosolv,bkg
	scale = w[0]
	rcore = w[1]
	thick = w[2]
	rhocore = w[3]
	rhosolv = rhocore
	rhoshel = w[4]
	bkg = w[5]
	
	// calculates scale *( f^2 + bkg)
	Variable bes,f,vol,qr,contr,f2
	
	// core first, then add in shell
	qr=x*rcore
	contr = rhocore-rhoshel
	bes = 3*(sin(qr)-qr*cos(qr))/qr^3
	vol = 4*pi/3*rcore^3
	f = vol*bes*contr
	//now the shell
	qr=x*(rcore+thick)
	contr = rhoshel-rhosolv
	bes = 3*(sin(qr)-qr*cos(qr))/qr^3
	vol = 4*pi/3*(rcore+thick)^3
	f += vol*bes*contr
	
	// normalize to the particle volume and rescale from [A-1] to [cm-1]
	//note that for the vesicle model, the volume is ONLY the shell volume
	vol = 4*pi/3*((rcore+thick)^3-rcore^3)
	f2 = f*f/vol*1.0e8
	
	//scale if desired
	f2 *= scale
	// then add in the background
	f2 += bkg
	
	return (f2)
End

// this is all there is to the smeared calculation!
Function SmearedVesicleForm(w,x) :FitFunc
	Wave w
	Variable x
	
	Variable ans
	SVAR sq = gSig_Q
	SVAR qb = gQ_bar
	SVAR sh = gShadow
	SVAR gQ = gQVals
	
	//the name of your unsmeared model is the first argument
	ans = Smear_Model_20(VesicleForm,$sq,$qb,$sh,$gQ,w,x)	//CH#4

	return(ans)
End

Macro Vesicle_Volume_N_Rg()
	Variable totVol,core,shell,i0,nden,rhoCore,rhoShell,rhoSolvent
	Variable phi
	
	if(WaveExists(coef_vesicle)==0)
		abort "You need to plot the vesicle model first to create the coefficient table"
	Endif
	totvol=4*pi/3*(coef_vesicle[1]+coef_vesicle[2])^3
	core=4*pi/3*(coef_vesicle[1])^3
	shell = totVol-core
	
//	nden = phi/(shell volume) or phi/Vtotal
	nden = coef_vesicle[0]/shell
	rhoCore = coef_vesicle[3]
	rhoShell = coef_vesicle[4]
	rhoSolvent = rhoCore
	
	i0 = nden*shell*shell*(rhoCore-rhoShell)^2*1e8
	Print "Total Volume [A^3] = ",totVol
	Print "Core Volume [A^3] = ",core
	Print "Shell Volume [A^3] = ",shell
	Print "Material volume fraction = ",coef_vesicle[0]
	Print "Excluded volume fraction = ",nden*totvol
//	Print "I(q=0) = ",i0
	Print "I(Q=0) = n Vshell^2(DR)^2 [1/cm] = ",i0
	Print "Number Density [1/A^3]= ",nden
//	Print "model I(0) = ",ywave_vesicle[0]
//	Print "model/limit = ",ywave_vesicle[0]/i0
	
	CalcRg_Vesicle(coef_vesicle)
End


Function CalcRg_Vesicle(coef_vesicle)
	Wave coef_vesicle

	Variable Rc,Rsh,r1,r2,rs,ans
	
	Rc = coef_vesicle[1]
	Rsh = Rc + coef_vesicle[2]
	r1 = coef_vesicle[3]
	r2 = coef_vesicle[4]
	rs = coef_vesicle[3]
	
//	ans = 0
//	ans = ( (r1-r2)/(r2-rs) )*Rc^5/Rsh^5 - 1
//	ans /= ( (r1-r2)/(r2-rs) )*Rc^3/Rsh^3 - 1
//	ans *= 3/5*Rsh^2
//	Print "Rg of vesicle [A] = ",sqrt(ans)
	
	ans = 0
	ans = Rc^5/Rsh^5 + 1
	ans /= Rc^3/Rsh^3 + 1
	ans *= 3/5*Rsh^2
	
	Print "Rg of vesicle [A] = ",sqrt(ans)
End
