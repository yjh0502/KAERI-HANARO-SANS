#pragma rtGlobals=1		// Use modern global access method.
#pragma IgorVersion=6.1

#include "sphere_v40"
// plots the form factor of  spheres with a Gaussian radius distribution
//
// also can plot the distribution itself, based on the current model parameters
//
// integration is currently done using 20-pt quadrature, but may benefit from 
//switching to an adaptive integration.
//

Proc PlotGaussSpheres(num,qmin,qmax)
	Variable num=128,qmin=0.001,qmax=0.7
	Prompt num "Enter number of data points for model: "
	Prompt qmin "Enter minimum q-value (A^-1) for model: "
	Prompt qmax "Enter maximum q-value (A^-1) for model: "
	
	Make/O/D/N=(num) xwave_pgs,ywave_pgs
	xwave_pgs = alog( log(qmin) + x*((log(qmax)-log(qmin))/num) )
	Make/O/D coef_pgs = {0.01,60,0.2,1e-6,3e-6,0.001}
	make/O/T parameters_pgs = {"Volume Fraction (scale)","mean radius (A)","polydisp (sig/avg)","SLD sphere (A-2)","SLD solvent (A-2)","bkg (cm-1 sr-1)"}
	Edit parameters_pgs,coef_pgs
	
	Variable/G root:g_pgs
	g_pgs := GaussSpheres(coef_pgs,ywave_pgs,xwave_pgs)
	Display ywave_pgs vs xwave_pgs
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
	
	AddModelToStrings("GaussSpheres","coef_pgs","parameters_pgs","pgs")
End

// - sets up a dependency to a wrapper, not the actual SmearedModelFunction
Proc PlotSmearedGaussSpheres(str)								
	String str
	Prompt str,"Pick the data folder containing the resolution you want",popup,getAList(4)
	
	// if any of the resolution waves are missing => abort
	if(ResolutionWavesMissingDF(str))		//updated to NOT use global strings (in GaussUtils)
		Abort
	endif
	
	SetDataFolder $("root:"+str)
	
	// Setup parameter table for model function
	Make/O/D smear_coef_pgs = {0.01,60,0.2,1e-6,3e-6,0.001}					
	make/o/t smear_parameters_pgs = {"Volume Fraction (scale)","mean radius (A)","polydisp (sig/avg)","SLD sphere (A-2)","SLD solvent (A-2)","bkg (cm-1 sr-1)"}	
	Edit smear_parameters_pgs,smear_coef_pgs					
	
	// output smeared intensity wave, dimensions are identical to experimental QSIG values
	// make extra copy of experimental q-values for easy plotting
	Duplicate/O $(str+"_q") smeared_pgs,smeared_qvals				
	SetScale d,0,0,"1/cm",smeared_pgs							
					
	Variable/G gs_pgs=0
	gs_pgs := fSmearedGaussSpheres(smear_coef_pgs,smeared_pgs,smeared_qvals)	//this wrapper fills the STRUCT
	
	Display smeared_pgs vs smeared_qvals									
	ModifyGraph log=1,marker=29,msize=2,mode=4
	Label bottom "q (A\\S-1\\M)"
	Label left "Intensity (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
	
	SetDataFolder root:
	AddModelToStrings("SmearedGaussSpheres","smear_coef_pgs","smear_parameters_pgs","pgs")
End
	



//AAO version, uses XOP if available
// simply calls the original single point calculation with
// a wave assignment (this will behave nicely if given point ranges)
Function GaussSpheres(cw,yw,xw) : FitFunc
	Wave cw,yw,xw
	
#if exists("GaussSpheresX")
	MultiThread yw = GaussSpheresX(cw,xw)
#else
	yw = fGaussSpheres(cw,xw)
#endif
	return(0)
End

Function fGaussSpheres(w,xx) : FitFunc
	wave w
	variable xx
	
	Variable scale,rad,pd,sig,rho,rhos,bkg,delrho
	
	//set up the coefficient values
	scale=w[0]
	rad=w[1]
	pd=w[2]
	sig=pd*rad
	rho=w[3]
	rhos=w[4]
	delrho=rho-rhos
	bkg=w[5]
	
//temp set scale=1 and bkg=0 for quadrature calc
	Make/O/D/N=5 sphere_temp
	sphere_temp[0] = 1
	sphere_temp[1] = rad		//changed in loop
	sphere_temp[2] = rho
	sphere_temp[3] = rhos
	sphere_temp[4] = 0
	
	//could use 5 pt quadrature to integrate over the size distribution, since it's a gaussian
	//currently using 20 pts...
	Variable va,vb,ii,zi,nord,yy,summ,inten
	String weightStr,zStr
	
	//select number of gauss points by setting nord=20 or76 points
	nord = 20
//	nord = 76
	
	weightStr = "gauss"+num2str(nord)+"wt"
	zStr = "gauss"+num2str(nord)+"z"
	
	if (WaveExists($weightStr) == 0) // wave reference is not valid, 
		Make/D/N=(nord) $weightStr,$zStr
		Wave gauWt = $weightStr
		Wave gauZ = $zStr		// wave references to pass
		if(nord==20)
			Make20GaussPoints(gauWt,gauZ)
		else
			Make76GaussPoints(gauWt,gauZ)
		endif	
	else
		if(exists(weightStr) > 1) 
			 Abort "wave name is already in use"		//executed only if name is in use elsewhere
		endif
		Wave gauWt = $weightStr
		Wave gauZ = $zStr		// create the wave references
	endif
	
	// end points of integration
	// limits are technically 0-inf, but wisely choose interesting region of q where R() is nonzero
	// +/- 3 sigq catches 99.73% of distrubution
	// change limits (and spacing of zi) at each evaluation based on R()
	//integration from va to vb
	va = -4*sig + rad
	if (va<0)
		va=0		//to avoid numerical error when  va<0 (-ve q-value)
	endif
	vb = 4*sig +rad
	
	summ = 0.0		// initialize integral
	Make/O/N=1 tmp_yw,tmp_xw
	tmp_xw[0] = xx
	for(ii=0;ii<nord;ii+=1)
		// calculate Gauss points on integration interval (r-value for evaluation)
		zi = ( gauZ[ii]*(vb-va) + vb + va )/2.0
		sphere_temp[1] = zi
		// calculate sphere scattering
		SphereForm(sphere_temp,tmp_yw,tmp_xw)		// AAO calculation, one point
		yy = gauWt[ii] *  Gauss_distr(sig,rad,zi) * tmp_yw[0]
		yy *= 4*pi/3*zi*zi*zi		//un-normalize by current sphere volume
		
		summ += yy		//add to the running total of the quadrature
   	endfor
// calculate value of integral to return
	inten = (vb-va)/2.0*summ
	
	//re-normalize by polydisperse sphere volume
	inten /= (4*pi/3*rad^3)*(1+3*pd^2)
	
	inten *= scale
	inten+=bkg
	
	Return(inten)
End

//wrapper to calculate the smeared model as an AAO-Struct
// fills the struct and calls the ususal function with the STRUCT parameter
//
// used only for the dependency, not for fitting
//
Function fSmearedGaussSpheres(coefW,yW,xW)
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
	err = SmearedGaussSpheres(fs)
	
	return (0)
End

// this is all there is to the smeared calculation!
Function SmearedGaussSpheres(s) :FitFunc
	Struct ResSmearAAOStruct &s

//	the name of your unsmeared model (AAO) is the first argument
	Smear_Model_20(GaussSpheres,s.coefW,s.xW,s.yW,s.resW)

	return(0)
End



//calculates number density given the coefficients of the Gaussian distribution
// the scale factor is the volume fraction
// then nden = phi/<V> where <V> is calculated using the 3rd moment of the radius
Macro NumberDensity_Gauss()

	Variable nden,vpoly,Ravg,p,Rg,I0,Sv,phi
	
	if(Exists("coef_pgs")!=1)
		abort "You need to plot the unsmeared model first to create the coefficient table"
	Endif
	Ravg = coef_pgs[1]  // mean radius (A)
	p = coef_pgs[2]  // polydispersity
	phi = coef_pgs[0]  // volume fraction
	Print "mean radius (A) = ",Ravg
	Print "polydispersity (sig/avg) = ",p
	Print "volume fraction = ",phi
	
	//re-normalize by polydisperse sphere volume
	vpoly = (4*pi/3*Ravg^3)*(1+3*p^2)
	nden = phi/vpoly		//nden in 1/A^3
	
	Print "number density (A^-3) = ",nden
	
	Rg = Ravg*(0.6)^0.5*(1+28*p^2+210*p^4+420*p^6+105*p^8) / (1+15*p^2+45*p^4+15*p^6)
	Print "Guinier Radius (A) = ",Rg
	I0 = 1.0e8*(4./3.)*pi*phi*(coef_pgs[3]- coef_pgs[4])^2*Ravg^3*(1+15*p^2+45*p^4+15*p^6)/(1+3*p^2)
	Print "Forward scattering cross-section (cm-1 sr-1) I(0)= ",I0
	Sv=1.0e8*(3*phi/Ravg)*(1+p^2)/(1+3*p^2)
	Print "Interfacial surface area per unit sample volume (cm-1) Sv= ",Sv	
	End

// plots the Gauss distribution based on the coefficient values
// a static calculation, so re-run each time
//
Macro PlotGaussDistribution()

	variable pd,avg,zz,maxr
	
	if(Exists("coef_pgs")!=1)
		abort "You need to plot the unsmeared model first to create the coefficient table"
	Endif
	pd=coef_pgs[2]
	avg = coef_pgs[1]
	
	Make/O/D/N=1000 Gauss_distribution
	maxr =  avg*(1+10*pd)

	SetScale/I x, 0, maxr, Gauss_distribution
	Gauss_distribution = Gauss_distr(pd*avg,avg,x)
	Display Gauss_distribution
	legend
End


Function Gauss_distr(sig,avg,pt)
	Variable sig,avg,pt
	
	Variable retval
	
	retval = (1/ ( sig*sqrt(2*Pi)) )*exp(-(avg-pt)^2/sig^2/2)
	return(retval)
End