#pragma rtGlobals=1		// Use modern global access method.
#pragma IgorVersion=6.1

////////////////////////////////////////////////////
//
// model to calculate the scattering from a gel
//
// Reference:G. Evmenenko, E. Theunissedn, K. Mortensen, H. Reynaers
//					Polymer 42 (2001) 2907-2913. (equation 5)
//
// 		see also: Hecht, Horkay, Geissler, PHYSICAL REVIEW E, VOLUME 64, 041402 (eqn 1)
//
// Steve Kline 14 JUL 2004 (for Robert Knott)
// updated 6/2008
//
////////////////////////////////////////////////////

//this macro sets up all the necessary parameters and waves that are
//needed to calculate the model function.
//
Proc PlotGaussLorentzGel(num,qmin,qmax)
	Variable num=256, qmin=.001, qmax=.7
	Prompt num "Enter number of data points for model: "
	Prompt qmin "Enter minimum q-value (A^1) for model: " 
	Prompt qmax "Enter maximum q-value (A^1) for model: "
//
	Make/O/D/n=(num) xwave_GL_Gel, ywave_GL_Gel
	xwave_GL_Gel =  alog(log(qmin) + x*((log(qmax)-log(qmin))/num))
	Make/O/D coef_GL_Gel = {100,100,50,20,0}
	make/o/t parameters_GL_Gel = {"Gauss Scale Factor, IG(0) ", "Static correlation Z (A)","Lorentzian Scale Factor IL(0)","Dynamic correlation z (A)","Incoherent Bgd (cm-1)"}
	Edit parameters_GL_Gel, coef_GL_Gel
	ModifyTable width(parameters_GL_Gel)=160
	
	Variable/G root:g_GL_Gel
	g_GL_gel  := GaussLorentzGel(coef_GL_Gel, ywave_GL_Gel, xwave_GL_Gel)
	Display ywave_GL_Gel vs xwave_GL_Gel
	ModifyGraph log=1,marker=29, msize=2, mode=4
	Label bottom "q (A\\S-1\\M) "
	Label left "I(q) (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
	
	AddModelToStrings("GaussLorentzGel","coef_GL_Gel","parameters_GL_Gel","GL_Gel")
//
End


// - sets up a dependency to a wrapper, not the actual SmearedModelFunction
Proc PlotSmearedGaussLorentzGel(str)								
	String str
	Prompt str,"Pick the data folder containing the resolution you want",popup,getAList(4)
	
	// if any of the resolution waves are missing => abort
	if(ResolutionWavesMissingDF(str))		//updated to NOT use global strings (in GaussUtils)
		Abort
	endif
	
	SetDataFolder $("root:"+str)
	
	// Setup parameter table for model function
	Make/O/D smear_coef_GL_Gel = {100,100,50,20,0}
	make/o/t smear_parameters_GL_Gel = {"Gauss Scale Factor, IG(0) ", "Static correlation Z (A)","Lorentzian Scale Factor IL(0)","Dynamic correlation z (A)","Incoherent Bgd (cm-1)"}	
	Edit smear_parameters_GL_Gel,smear_coef_GL_Gel					//display parameters in a table
	ModifyTable width(smear_parameters_GL_Gel)=160				
	
	Duplicate/O $(str+"_q") smeared_GL_Gel,smeared_qvals
	SetScale d,0,0,"1/cm",smeared_GL_Gel					
		
	Variable/G gs_GL_Gel=0
	gs_GL_Gel := fSmearedGaussLorentzGel(smear_coef_GL_Gel,smeared_GL_Gel,smeared_qvals)	//this wrapper fills the STRUCT
	Display smeared_GL_Gel vs smeared_qvals								
	
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (�\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
	
	SetDataFolder root:
	AddModelToStrings("SmearedGaussLorentzGel","smear_coef_GL_Gel","smear_parameters_GL_Gel","GL_Gel")
End

//AAO version, uses XOP if available
// simply calls the original single point calculation with
// a wave assignment (this will behave nicely if given point ranges)
Function GaussLorentzGel(cw,yw,xw) : FitFunc
	Wave cw,yw,xw
	
#if exists("GaussLorentzGelX")
	yw = GaussLorentzGelX(cw,xw)
#else
	yw = fGaussLorentzGel(cw,xw)
#endif
	return(0)
End

//
Function fGaussLorentzGel(w,x) : FitFunc
	Wave w
	Variable x
//	 Input (fitting) variables are:
	//[0] Gaussian scale factor
	//[1] Gaussian (static) screening length
	//[2] Lorentzian (fluctuation) scale factor
	//[3] Lorentzian screening length
	//[4] incoherent background
//	give them nice names
	Variable Ig0,gg,Il0,ll,bgd
	Ig0 = w[0]
	gg = w[1]
	Il0 = w[2]
	ll = w[3]
	bgd = w[4]
	
//	local variables
	Variable inten

	inten = Ig0*exp(-x*x*gg*gg/2) + Il0/(1 + (x*ll)^2) + bgd
	Return (inten)
End

//
Function fSmearedGaussLorentzGel(coefW,yW,xW)
	Wave coefW,yW,xW
	
	String str = getWavesDataFolder(yW,0)
	String DF="root:"+str+":"
	
	WAVE resW = $(DF+str+"_res")
	
	STRUCT ResSmearAAOStruct fs
	WAVE fs.coefW = coefW		//is this the proper way to populate? seems redundant...
	WAVE fs.yW = yW
	WAVE fs.xW = xW
	WAVE fs.resW = resW
	
	Variable err
	err = SmearedGaussLorentzGel(fs)
	
	return (0)
End

// smeared calculation, AAO and using a structure...
// defined as as STRUCT, there can never be a dependency linked directly to this function
// - so set a dependency to the wrapper
//
// like the unsmeared function, AAO is equivalent to a wave assignment to the point calculation
// - but now the function passed is an AAO function
//
// Smear_Model_20() takes care of what calculation is done, depending on the resolution information
//
//
Function SmearedGaussLorentzGel(s) : FitFunc
	Struct ResSmearAAOStruct &s

////the name of your unsmeared model is the first argument
	Smear_Model_20(GaussLorentzGel,s.coefW,s.xW,s.yW,s.resW)

	return(0)
End