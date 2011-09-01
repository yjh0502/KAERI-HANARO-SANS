#pragma rtGlobals=1		// Use modern global access method.

////////////////////////////////////////////////
// GaussUtils.proc and PlotUtils.proc MUST be included for the smearing calculation to compile
// Adopting these into the experiment will insure that they are always present
////////////////////////////////////////////////
// this function is for the form factor of a right circular cylinder with uniform scattering length density
//
// 06 NOV 98 SRK
////////////////////////////////////////////////

Proc PlotCylinderForm(num,qmin,qmax)
	Variable num=128,qmin=0.001,qmax=0.7
	Prompt num "Enter number of data points for model: "
	Prompt qmin "Enter minimum q-value (A^-1) for model: "
	Prompt qmax "Enter maximum q-value (A^-1) for model: "
	
	make/o/D/n=(num) xwave_cyl,ywave_cyl
	xwave_cyl =  alog(log(qmin) + x*((log(qmax)-log(qmin))/num))
	make/o/D coef_cyl = {1.,20.,400,3.0e-6,0.01}
	make/o/t parameters_cyl = {"scale","radius (A)","length (A)","contrast (A^-2)","incoh. bkg (cm^-1)"}
	Edit parameters_cyl,coef_cyl
	ywave_cyl := CylinderForm(coef_cyl,xwave_cyl)
	Display ywave_cyl vs xwave_cyl
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
End
///////////////////////////////////////////////////////////

Proc PlotSmearedCylinderForm()	
	//no input parameters necessary, it MUST use the experimental q-values
	// from the experimental data read in from an AVE/QSIG data file
	
	// if no gQvals wave, data must not have been loaded => abort
	if(ResolutionWavesMissing())
		Abort
	endif
	
	// Setup parameter table for model function
	make/o/D smear_coef_cyl = {1.,20.,400,3.0e-6,0.01}
	make/o/t smear_parameters_cyl = {"scale","radius (A)","length (A)","contrast (A^-2)","incoh. bkg (cm^-1)"}
	Edit smear_parameters_cyl,smear_coef_cyl
	
	// output smeared intensity wave, dimensions are identical to experimental QSIG values
	// make extra copy of experimental q-values for easy plotting
	Duplicate/O $gQvals smeared_cyl,smeared_qvals
	SetScale d,0,0,"1/cm",smeared_cyl	

	smeared_cyl := SmearedCylinderForm(smear_coef_cyl,$gQvals)
	Display smeared_cyl vs smeared_qvals
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
End

///////////////////////////////////////////////////////////////
// unsmeared model calculation
///////////////////////////
Function CylinderForm(w,x) : FitFunc
	Wave w
	Variable x

//#if exists("CylinderFormX")
//	return CylinderFormX(w,x)
//#endif

//	if(exists("CylinderFormX")==3)
//		FUNCREF SANSModel_proto func=$"CylinderFormX"
//		return func(w,x)			//defined this way to hide the functionX name from the compiler
//	endif
	
//The input variables are (and output)
	//[0] scale
	//[1] cylinder RADIUS (A)
	//[2] total cylinder LENGTH (A)
	//[3] contrast (A^-2)
	//[4] background (cm^-1)
	Variable scale, radius,length,delrho,bkg
	scale = w[0]
	radius = w[1]
	length = w[2]
	delrho = w[3]
	bkg = w[4]
//
// the OUTPUT form factor is <f^2>/Vcyl [cm-1]
//

// local variables
	Variable nord,ii,va,vb,contr,vcyl,nden,summ,yyy,zi,qq,halfheight
	Variable answer
	String weightStr,zStr
	
	weightStr = "gauss76wt"
	zStr = "gauss76z"

	
//	if wt,z waves don't exist, create them
// 20 Gauss points is not enough for cylinder calculation
	
	if (WaveExists($weightStr) == 0) // wave reference is not valid, 
		Make/D/N=76 $weightStr,$zStr
		Wave w76 = $weightStr
		Wave z76 = $zStr		// wave references to pass
		Make76GaussPoints(w76,z76)	
	//		    printf "w[0],z[0] = %g %g\r", w76[0],z76[0]
	else
		if(exists(weightStr) > 1) 
			 Abort "wave name is already in use"	// execute if condition is false
		endif
		Wave w76 = $weightStr
		Wave z76 = $zStr		// Not sure why this has to be "declared" twice
	//	    printf "w[0],z[0] = %g %g\r", w76[0],z76[0]	
	endif


// set up the integration
	// end points and weights
	nord = 76
	va = 0
	vb = Pi/2.0
      halfheight = length/2.0

// evaluate at Gauss points 
	// remember to index from 0,size-1

	qq = x		//current x point is the q-value for evaluation
      summ = 0.0		// initialize integral
      ii=0
      do
		// Using 76 Gauss points
		zi = ( z76[ii]*(vb-va) + vb + va )/2.0		
		yyy = w76[ii] * cyl(qq, radius, halfheight, zi)
		summ += yyy 

        	ii+=1
	while (ii<nord)				// end of loop over quadrature points
//   
// calculate value of integral to return

      answer = (vb-va)/2.0*summ
      
// Multiply by contrast^2
	answer *= delrho*delrho
//normalize by cylinder volume
//NOTE that for this (Fournet) definition of the integral, one must MULTIPLY by Vcyl
	vcyl=Pi*radius*radius*length
	answer *= vcyl
//convert to [cm-1]
	answer *= 1.0e8
//Scale
	answer *= scale
// add in the background
	answer += bkg

	Return (answer)
	
End		//End of function CylinderForm()

///////////////////////////////////////////////////////////////
Function cyl(qq,rr,h,theta)
	Variable qq,rr,h,theta
	
// qq is the q-value for the calculation (1/A)
// rr is the radius of the cylinder (A)
// h is the HALF-LENGTH of the cylinder = L/2 (A)

   //Local variables 
	Variable besarg,bj,retval,d1,t1,b1,t2,b2
    besarg = qq*rr*sin(theta)

    bj =bessJ(1,besarg)

//* Computing 2nd power */
    d1 = sin(qq * h * cos(theta))
    t1 = d1 * d1
//* Computing 2nd power */
    d1 = bj
    t2 = d1 * d1 * 4.0 * sin(theta)
//* Computing 2nd power */
    d1 = qq * h * cos(theta)
    b1 = d1 * d1
//* Computing 2nd power */
    d1 = qq * rr * sin(theta)
    b2 = d1 * d1
    retval = t1 * t2 / b1 / b2

    return retval
    
End 	//Function cyl()

// this is all there is to the smeared calculation!
Function SmearedCylinderForm(w,x) :FitFunc
	Wave w
	Variable x
	
	Variable ans
	SVAR sq = gSig_Q
	SVAR qb = gQ_bar
	SVAR sh = gShadow
	SVAR gQ = gQVals
	
	//the name of your unsmeared model is the first argument
//	if(exists("CylinderFormX") == 3)
//		ans = Smear_Model_20($"CylinderFormX",$sq,$qb,$sh,$gQ,w,x)
//	else
		ans = Smear_Model_20(CylinderForm,$sq,$qb,$sh,$gQ,w,x)
//	endif

	return(ans)
End

