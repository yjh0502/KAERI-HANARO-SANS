#pragma rtGlobals=1		// Use modern global access method.

//#include "GaussUtils"
//#include "PlotUtils"

////////////////////////////////////////////////////
//
// calculates the scattering from a triaxial ellipsoid
// with semi-axes a <= b <= c
// 
// - the user must make sure that the constraints are not violated
// otherwise the calculation will not be correct
//
// a double integral is used, both using Gaussian quadrature
// routines that are now included with GaussUtils
// 20-pt quadrature appears to be enough, 76 pt is available
// by changing the function calls
//
////////////////////////////////////////////////////

//this macro sets up all the necessary parameters and waves that are
//needed to calculate the model function.
//
Proc Plot_TriaxialEllipsoid(num,qmin,qmax)
	Variable num=100, qmin=.001, qmax=.7
	Prompt num "Enter number of data points for model: "
	Prompt qmin "Enter minimum q-value (A^1) for model: " 
	Prompt qmax "Enter maximum q-value (A^1) for model: "
	//
	Make/O/D/n=(num) xwave_triax, ywave_triax
	xwave_triax =  alog(log(qmin) + x*((log(qmax)-log(qmin))/num))
	Make/O/D coef_triax = {1,35,100,400,6e-6,0}			//CH#2
	make/o/t parameters_triax = {"Scale Factor","Semi-axis A [smallest](A)","Semi-axis B (A)","Semi-axis C [largest](A)","Contrast (A^-2)","Incoherent Bgd (cm-1)"}	//CH#3
	Edit parameters_triax, coef_triax
	ywave_triax  := TriaxialEllipsoid(coef_triax, xwave_triax)
	Display ywave_triax vs xwave_triax
	ModifyGraph marker=29, msize=2, mode=4
	ModifyGraph log=1
	Label bottom "q (A\\S-1\\M) "
	Label left "I(q) (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
//
End

//
//this Proc sets up all the necessary parameters and waves that are
//needed to calculate the  smeared model function.
//
//no input parameters are necessary, it MUST use the experimental q-values
// from the experimental data read in from an AVE/QSIG data file
////////////////////////////////////////////////////
Proc PlotSmeared_TriAxEllipsoid()								//triax
	// if no gQvals wave, data must not have been loaded => abort
	if(ResolutionWavesMissing())
		Abort
	endif
	
	// Setup parameter table for model function
	Make/O/D smear_coef_triax = {1,35,100,400,6e-6,0}		//CH#4
	make/o/t smear_parameters_triax = {"Scale Factor","A (A)","B (A)","C (A)","Contrast (A^-2)","Incoherent Bgd (cm-1)"}
	Edit smear_parameters_triax,smear_coef_triax					//display parameters in a table
	
	// output smeared intensity wave, dimensions are identical to experimental QSIG values
	// make extra copy of experimental q-values for easy plotting
	Duplicate/O $gQvals smeared_triax,smeared_qvals				//
	SetScale d,0,0,"1/cm",smeared_triax							//

	smeared_triax := Triax_Smeared(smear_coef_triax,$gQvals)		// SMEARED function name
	Display smeared_triax vs smeared_qvals									//
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "I(q) (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
End     // end macro 

// calculates the form factor of an ellipsoidal solid
// with semi-axes of a,b,c
// - a double integral - choose points wisely
//
Function TriaxialEllipsoid(w,x) : FitFunc
	Wave w
	Variable x
//	 Input (fitting) variables are:
	//[0] scale factor
	//[1] semi-axis A (A)
	//[2] semi-axis B (A)
	//[3] semi-axis C (A)
	//[4] contrast (A^-2)
	//[5] incoherent background (cm^-1)
//	give them nice names
	Variable scale,aa,bb,cc,contr,bkg,inten,qq,ii,arg,mu
	scale = w[0]
	aa = w[1]
	bb = w[2]
	cc = w[3]
	contr = w[4]
	bkg = w[5]
	
	Variable/G root:gDumY=0,root:gDumX=0
	
	inten = IntegrateFn20(TaE_Outer,0,1,w,x)
	
	inten *= 4*Pi/3*aa*cc*bb		//multiply by volume
	inten *= 1e8		//convert to cm^-1
	inten *= contr*contr
	inten *= scale
	inten += bkg
	
	Return (inten)
End

// outer integral
// x is the q-value - remember that "mu" in the notation = B*Q
Function TaE_Outer(w,x,dum)
	Wave w
	Variable x,dum
	
	Variable retVal,mu,aa,bb,cc,mudum,arg
	aa = w[1]
	bb = w[2]
	cc = w[3]
	
	NVAR dy = root:gDumY
	NVAR dx = root:gDumX
	dy = dum
	retval = IntegrateFn20(TaE_inner,0,1,w,x)
	
	return(retVal)
End

//returns the value of the integrand of the inner integral
Function TaE_Inner(w,x,dum)
	Wave w
	Variable x,dum
	
	Variable aa,bb,cc,retVal
	
	NVAR dy = root:gDumY
	NVAR dx = root:gDumX
	dx = dum
	aa = w[1]
	bb = w[2]
	cc = w[3]
	retVal = TaE(x,aa,bb,cc,dx,dy)
	
	return(retVal)
End

Function TaE(qq,aa,bb,cc,dx,dy)
	Variable qq,aa,bb,cc,dx,dy
	
	Variable val,arg
	arg = aa*aa*cos(pi*dx/2)*cos(pi*dx/2)
	arg += bb*bb*sin(pi*dx/2)*sin(pi*dx/2)*(1-dy*dy)
	arg += cc*cc*dy*dy
	arg = qq*sqrt(arg)
	
	val = 9*((sin(arg) - arg*cos(arg))/arg^3 )^2
	
	return(val)
end
		
// this is all there is to the smeared calculation!
Function Triax_Smeared(w,x) :FitFunc
	Wave w
	Variable x
	
	Variable ans
	SVAR sq = gSig_Q
	SVAR qb = gQ_bar
	SVAR sh = gShadow
	SVAR gQ = gQVals
	
	//the name of your unsmeared model is the first argument
	ans = Smear_Model_20(TriaxialEllipsoid,$sq,$qb,$sh,$gQ,w,x)

	return(ans)
End