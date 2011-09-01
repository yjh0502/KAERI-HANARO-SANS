#pragma rtGlobals=1		// Use modern global access method.#pragma IgorVersion=6.1//////////////////////////////////////////////////////// an empirical model containing low Q power law scattering + a lorentzian at higher Q//// B. Hammouda OCT 2008////// updated for use with latest macros SRK Nov 2008////////////////////////////////////////////////////////Proc PlotCorrLength(num,qmin,qmax)	Variable num=200, qmin=0.001, qmax=0.7	Prompt num "Enter number of data points for model: "	Prompt qmin "Enter minimum q-value (�^-1) for model: " 	Prompt qmax "Enter maximum q-value (�^-1) for model: "//	Make/O/D/n=(num) xwave_CorrLength, ywave_CorrLength	xwave_CorrLength =  alog(log(qmin) + x*((log(qmax)-log(qmin))/num))	Make/O/D coef_CorrLength = {1e-6, 3, 10, 50.0,2,0.1}			make/o/t parameters_CorrLength = {"Porod Scale", "Porod Exponent","Lorentzian Scale","Lor Screening Length [A]","Lorentzian Exponent","Bgd [1/cm]"}	//CH#2	Edit parameters_CorrLength, coef_CorrLength		Variable/G root:g_CorrLength	g_CorrLength := CorrLength(coef_CorrLength, ywave_CorrLength, xwave_CorrLength)	Display ywave_CorrLength vs xwave_CorrLength	ModifyGraph marker=29, msize=2, mode=4	ModifyGraph log=1,grid=1,mirror=2	Label bottom "q (�\\S-1\\M) "	Label left "I(q) (cm\\S-1\\M)"	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)		AddModelToStrings("CorrLength","coef_CorrLength","parameters_CorrLength","CorrLength")//End////no input parameters are necessary, it MUST use the experimental q-values// from the experimental data read in from an AVE/QSIG data file////////////////////////////////////////////////////// - sets up a dependency to a wrapper, not the actual SmearedModelFunctionProc PlotSmearedCorrLength(str)									String str	Prompt str,"Pick the data folder containing the resolution you want",popup,getAList(4)		// if any of the resolution waves are missing => abort	if(ResolutionWavesMissingDF(str))		//updated to NOT use global strings (in GaussUtils)		Abort	endif		SetDataFolder $("root:"+str)		// Setup parameter table for model function	Make/O/D smear_coef_CorrLength = {1e-6, 3, 10, 50.0,2,0.1}			make/o/t smear_parameters_CorrLength = {"Porod Scale", "Porod Exponent","Lorentzian Scale","Lor Screening Length [A]","Lorentzian Exponent","Bgd [1/cm]"}	Edit smear_parameters_CorrLength,smear_coef_CorrLength					//display parameters in a table		// output smeared intensity wave, dimensions are identical to experimental QSIG values	// make extra copy of experimental q-values for easy plotting	Duplicate/O $(str+"_q") smeared_CorrLength,smeared_qvals	SetScale d,0,0,"1/cm",smeared_CorrLength						Variable/G gs_CorrLength=0	gs_CorrLength := fSmearedCorrLength(smear_coef_CorrLength,smeared_CorrLength,smeared_qvals)	//this wrapper fills the STRUCT		Display smeared_CorrLength vs smeared_qvals	ModifyGraph log=1,marker=29,msize=2,mode=4	Label bottom "q (�\\S-1\\M)"	Label left "I(q) (cm\\S-1\\M)"	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)		SetDataFolder root:	AddModelToStrings("SmearedCorrLength","smear_coef_CorrLength","smear_parameters_CorrLength","CorrLength")End////AAO version, uses XOP if available// simply calls the original single point calculation with// a wave assignment (this will behave nicely if given point ranges)Function CorrLength(cw,yw,xw) : FitFunc	Wave cw,yw,xw	#if exists("CorrLengthX")	yw = CorrLengthX(cw,xw)#else	yw = fCorrLength(cw,xw)#endif	return(0)End//// unsmeared model calculation//Function fCorrLength(w,x) : FitFunc	Wave w	Variable x		// variables are:								//[0] Porod term scaling	//[1] Porod exponent	//[2] Lorentzian term scaling	//[3] Lorentzian screening length [A]	//[4] Lorentzian exponent	//[5] background		Variable aa,nn,cc,LL,mm,bgd	aa = w[0]	nn = w[1]	cc = w[2]	LL=w[3]	mm=w[4]	bgd=w[5]//	local variables	Variable inten, qval//	x is the q-value for the calculation	qval = x//	do the calculation and return the function value		inten = aa/(qval)^nn + cc/(1 + (qval*LL)^mm) + bgd	Return (inten)	End///////////////////////////////////////////////////////////////// smeared model calculation//// you don't need to do anything with this function, as long as// your CorrLength works correctly, you get the resolution-smeared// version for free.//// this is all there is to the smeared model calculation!Function SmearedCorrLength(s) : FitFunc	Struct ResSmearAAOStruct &s//	the name of your unsmeared model (AAO) is the first argument	Smear_Model_20(CorrLength,s.coefW,s.xW,s.yW,s.resW)	return(0)End///////////////////////////////////////////////////////////////// nothing to change here////wrapper to calculate the smeared model as an AAO-Struct// fills the struct and calls the ususal function with the STRUCT parameter//// used only for the dependency, not for fitting//Function fSmearedCorrLength(coefW,yW,xW)	Wave coefW,yW,xW		String str = getWavesDataFolder(yW,0)	String DF="root:"+str+":"		WAVE resW = $(DF+str+"_res")		STRUCT ResSmearAAOStruct fs	WAVE fs.coefW = coefW		WAVE fs.yW = yW	WAVE fs.xW = xW	WAVE fs.resW = resW		Variable err	err = SmearedCorrLength(fs)		return (0)End