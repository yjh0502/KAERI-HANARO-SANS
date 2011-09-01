#pragma rtGlobals=1		// Use modern global access method.
#pragma IgorVersion=6.1

///////////////////////////////////////////
// this function is for the form factor of an cylinder with an ellipsoidal cross-section
// and a uniform scattering length density
//
// 06 NOV 98 SRK
//
// re-written to not use MacOS XOP for calculation
// now requires the "new" version of GaussUtils that includes the generic quadrature routines
//
// 09 SEP 03 SRK
////////////////////////////////////////////////

Proc PlotEllipticalCylinder(num,qmin,qmax)
	Variable num=50,qmin=0.001,qmax=0.7
	Prompt num "Enter number of data points for model: "
	Prompt qmin "Enter minimum q-value (A^-1) for model: "
	Prompt qmax "Enter maximum q-value (A^-1) for model: "
	
//	//constants needed for the integration if qtrap is used (in a separate procedure file!)
//	Variable/G root:gNumPoints=200
//	Variable/G root:gTol=1e-5
//	Variable/G root:gMaxIter=20
	//
	Make/O/D/n=(num) xwave_ecf,ywave_ecf
	xwave_ecf =  alog(log(qmin) + x*((log(qmax)-log(qmin))/num))
	Make/O/D coef_ecf = {1.,20.,1.5,400,1.0e-6,6.3e-6,0.0}
	make/o/t parameters_ecf = {"scale","minor radius (A)","nu = major/minor (-)","length (A)","SLD cylinder (A^-2)","SLD solvent (A^-2)","incoh. bkg (cm^-1)"}
	Edit parameters_ecf,coef_ecf
	
	Variable/G root:g_ecf
	g_ecf := EllipticalCylinder(coef_ecf,ywave_ecf,xwave_ecf)
	Display ywave_ecf vs xwave_ecf
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
	
	AddModelToStrings("EllipticalCylinder","coef_ecf","parameters_ecf","ecf")
End
///////////////////////////////////////////////////////////

// - sets up a dependency to a wrapper, not the actual SmearedModelFunction
Proc PlotSmearedEllipticalCylinder(str)								
	String str
	Prompt str,"Pick the data folder containing the resolution you want",popup,getAList(4)
	
	// if any of the resolution waves are missing => abort
	if(ResolutionWavesMissingDF(str))		//updated to NOT use global strings (in GaussUtils)
		Abort
	endif
	
	SetDataFolder $("root:"+str)
	
	// Setup parameter table for model function
	Make/O/D smear_coef_ecf =  {1.,20.,1.5,400,1.0e-6,6.3e-6,0.0}
	make/o/t smear_parameters_ecf = {"scale","minor radius (A)","nu = major/minor (-)","length (A)","SLD cylinder (A^-2)","SLD solvent (A^-2)","incoh. bkg (cm^-1)"}
	Edit smear_parameters_ecf,smear_coef_ecf
	
	// output smeared intensity wave, dimensions are identical to experimental QSIG values
	// make extra copy of experimental q-values for easy plotting
	Duplicate/O $(str+"_q") smeared_ecf,smeared_qvals
	SetScale d,0,0,"1/cm",smeared_ecf	
					
	Variable/G gs_ecf=0
	gs_ecf := fSmearedEllipticalCylinder(smear_coef_ecf,smeared_ecf,smeared_qvals)	//this wrapper fills the STRUCT
	
	Display smeared_ecf vs smeared_qvals
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
	
	SetDataFolder root:
	AddModelToStrings("SmearedEllipticalCylinder","smear_coef_ecf","smear_parameters_ecf","ecf")
End



//AAO version, uses XOP if available
// simply calls the original single point calculation with
// a wave assignment (this will behave nicely if given point ranges)
//
// (MultiThread) yw = 0.044s (100 pts)
// XOP alone     yw = 0.082s
// Igor code     yw = 0.34s  (Thread = 7.4 x faster)
//
Function EllipticalCylinder(cw,yw,xw) : FitFunc
	Wave cw,yw,xw
	
//	Variable t1=StopMSTimer(-2)

#if exists("EllipticalCylinderX")
	MultiThread yw = EllipticalCylinderX(cw,xw)
#else
	yw = fEllipticalCylinder(cw,xw)
#endif

//	Print "elapsed time = ",(StopMSTimer(-2) - t1)/1e6

	return(0)
End

// the main function that calculates the form factor of an elliptical cylinder
// integrates EllipCyl_integrand, which itself is an integral function
// 20 points of quadrature seems to be sufficient for both integrals
//
Function fEllipticalCylinder(w,x) 	: FitFunc
	Wave w
	Variable x
	
	Variable inten,scale,rad,nu,len,contr,bkg,ii,sldc,slds
	scale = w[0]
	rad = w[1]
	nu = w[2]
	len = w[3]
	sldc = w[4]
	slds = w[5]
	contr = sldc - slds
	bkg = w[6]
	
	inten = IntegrateFn20(EllipCyl_Integrand,0,1,w,x)
	
	//multiply by volume
	inten *= Pi*rad*rad*nu*len
	inten *= 1e8	//convert to 1/cm
	inten *= contr*contr
	inten *= scale
	inten += bkg
	
	return(inten)
End

//the outer integral
Function EllipCyl_Integrand(w,x,dum)
	Wave w
	Variable x,dum
	
	Variable val,rad,arg,len
	rad = w[1]
	len = w[3]
	
	arg = rad*sqrt(1-dum^2)
	duplicate/O w temp_w
	Wave temp_w=temp_w
	temp_w[1] = arg		//replace radius with transformed variable
	val = (1/pi)*IntegrateFn20(Phi_EC,0,Pi,temp_w,x)
	
	// equivalent to the 20-pt quadrature
//	val = (1/pi)*qtrap(Phi_EC,temp_w,x,0,Pi,1e-3,20)
	
	arg = x*len*dum/2
	if(arg==0)
		val *= 1
	else
		val *= sin(arg)*sin(arg)/arg/arg
	endif
	//Print "val=",val
	return(val)
End

//the inner integral
Function Phi_EC(w,x,dum)
	Wave w
	Variable x,dum
	
	Variable ans,arg,aa,nu
	aa = w[1]		// = rad*sqrt(1-dum^2)
	nu = w[2]
	arg = x*aa*sqrt( (1+nu^2)/2 + (1-nu^2)/2*cos(dum) )
	if(arg==0)
		ans = (2*0.5)^2		// == 1
	else
		ans = 2*2*bessJ(1,arg)*bessJ(1,arg)/arg/arg
	endif
	return(ans)
End

//wrapper to calculate the smeared model as an AAO-Struct
// fills the struct and calls the ususal function with the STRUCT parameter
//
// used only for the dependency, not for fitting
//
Function fSmearedEllipticalCylinder(coefW,yW,xW)
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
	err = SmearedEllipticalCylinder(fs)
	
	return (0)
End

// this is all there is to the smeared calculation!
Function SmearedEllipticalCylinder(s) :FitFunc
	Struct ResSmearAAOStruct &s

//	the name of your unsmeared model (AAO) is the first argument
	Smear_Model_20(EllipticalCylinder,s.coefW,s.xW,s.yW,s.resW)

	return(0)
End
	