#pragma rtGlobals=1		// Use modern global access method.
#pragma IgorVersion=6.1

//
//
// Simple Cubic paracrystal, powder average
//
// VERY slow, since the function is so ill-behaved and needs LOTS of quadrature
// points. Adaptive methods were even slower and troublesom to converge,
// although in theory they should be a better choice than blindly increasing the number of points.
//
// 150 points seems to give reasonable reproduction of the peak heights in the paper.
// peak locations are correct
// 76 points of quadrature for the smearing is only a guess, it's not been tested yet.
//
// Original implementation - Danilo Pozzo
//		modified and modernized for more efficient integration SRK Nov 2008
//
//REFERENCE 
//Hideki Matsuoka etal. Physical Review B, Vol 36 Num 3, p1754 1987   ORIGINAL PAPER
//Hideki Matsuoka etal. Physical Review B, Vol 41 Num 6, p3854 1990   CORRECTIONS TO PAPER
//
////////////////////////////////////////////////////



Proc PlotSC_ParaCrystal(num,qmin,qmax)
	Variable num=100, qmin=0.001, qmax=0.7
	Prompt num "Enter number of data points for model: "
	Prompt qmin "Enter minimum q-value (�^-1) for model: " 
	Prompt qmax "Enter maximum q-value (�^-1) for model: "
//
	Make/O/D/n=(num) xwave_SC_ParaCrystal, ywave_SC_ParaCrystal
	xwave_SC_ParaCrystal =  alog(log(qmin) + x*((log(qmax)-log(qmin))/num))
	Make/O/D coef_SC_ParaCrystal = {1,220,0.06,40,3e-6,6.3e-6,0.0}
	make/o/t parameters_SC_ParaCrystal = {"scale","Nearest Neighbor (A)","distortion, g","Sphere Radius (A)","SLD sphere (A-2)","SLD solvent (A-2)", "Background (cm-1)"}	
	Edit parameters_SC_ParaCrystal, coef_SC_ParaCrystal
	
	Variable/G root:gNordSC=150
	
	Variable/G root:g_SC_ParaCrystal
	g_SC_ParaCrystal := SC_ParaCrystal(coef_SC_ParaCrystal, ywave_SC_ParaCrystal, xwave_SC_ParaCrystal)
	Display ywave_SC_ParaCrystal vs xwave_SC_ParaCrystal
	ModifyGraph marker=29, msize=2, mode=4
	ModifyGraph grid=1,mirror=2
	ModifyGraph log=0
	Label bottom "q (�\\S-1\\M) "
	Label left "I(q) (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
	
	AddModelToStrings("SC_ParaCrystal","coef_SC_ParaCrystal","parameters_SC_ParaCrystal","SC_ParaCrystal")
//
End

//
//this macro sets up all the necessary parameters and waves that are
//needed to calculate the  smeared model function.
//
//no input parameters are necessary, it MUST use the experimental q-values
// from the experimental data read in from an AVE/QSIG data file
////////////////////////////////////////////////////
// - sets up a dependency to a wrapper, not the actual SmearedModelFunction
Proc PlotSmearedSC_ParaCrystal(str)								
	String str
	Prompt str,"Pick the data folder containing the resolution you want",popup,getAList(4)
	
	// if any of the resolution waves are missing => abort
	if(ResolutionWavesMissingDF(str))		//updated to NOT use global strings (in GaussUtils)
		Abort
	endif
	
	SetDataFolder $("root:"+str)
	
	// Setup parameter table for model function
	Make/O/D smear_coef_SC_ParaCrystal = {1,220,0.06,40,3e-6,6.3e-6,0.0}
	make/o/t smear_parameters_SC_ParaCrystal = {"scale","Nearest Neighbor (A)","distortion, g","Sphere Radius (A)","SLD sphere (A-2)","SLD solvent (A-2)", "Background (cm-1)"}
	Edit smear_parameters_SC_ParaCrystal,smear_coef_SC_ParaCrystal					//display parameters in a table
	
	// output smeared intensity wave, dimensions are identical to experimental QSIG values
	// make extra copy of experimental q-values for easy plotting
	Duplicate/O $(str+"_q") smeared_SC_ParaCrystal,smeared_qvals
	SetScale d,0,0,"1/cm",smeared_SC_ParaCrystal
	
	Variable/G gNordSC = 150	
	Variable/G gs_SC_ParaCrystal=0
	gs_SC_ParaCrystal := fSmearedSC_ParaCrystal(smear_coef_SC_ParaCrystal,smeared_SC_ParaCrystal,smeared_qvals)	//this wrapper fills the STRUCT
	
	Display smeared_SC_ParaCrystal vs smeared_qvals
	ModifyGraph marker=29,msize=2,mode=4
	ModifyGraph log=0
	Label bottom "q (�\\S-1\\M)"
	Label left "I(q) (cm\\S-1\\M)"
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
	
	SetDataFolder root:
	AddModelToStrings("SmearedSC_ParaCrystal","smear_coef_SC_ParaCrystal","smear_parameters_SC_ParaCrystal","SC_ParaCrystal")
End



// Threaded version
// Threaded XOP = 2.46 s
// non-threaded XOP = 4.48s (1.8x speedup)
// non-threaded, non-XOP = 39.8 s
//  overall = x 16 speedup !
//
Function SC_ParaCrystal(cw,yw,xw) : FitFunc
	Wave cw,yw,xw

//	Variable t1=StopMSTimer(-2)


/////// NO threading /////////
//#if exists("SC_ParaCrystalX")
//	yw = SC_ParaCrystalX(cw,xw)
//#else
//	yw = fSC_ParaCrystal(cw,xw)
//#endif


///// THREADING ///////

			
#if exists("SC_ParaCrystalX")

////////
//	Variable npt=numpnts(yw)
//	Variable i,nthreads= ThreadProcessorCount
//	variable mt= ThreadGroupCreate(nthreads)
//
//	for(i=0;i<nthreads;i+=1)
//	//	Print (i*npt/nthreads),((i+1)*npt/nthreads-1)
//		ThreadStart mt,i,SC_ParaCrystal_T(cw,yw,xw,(i*npt/nthreads),((i+1)*npt/nthreads-1))
//	endfor
//
//	do
//		variable tgs= ThreadGroupWait(mt,100)
//	while( tgs != 0 )
//
//	variable dummy= ThreadGroupRelease(mt)
/////
	
	MultiThread 	yw = SC_ParaCrystalX(cw,xw)

//// to return just Z(q), undo the form factor calculation
//	Variable latticeScale
//	latticeScale = 4*(4/3)*pi*(cw[3]^3)/((cw[1]*(2^0.5))^3)	
//	
//	yw /= SphereForm_SC(cw[3],cw[4]-cw[5],xw)*latticeScale
////	

#else
	yw = fSC_ParaCrystal(cw,xw)			// Igor code is NOT threaded, for lots of good reasons
#endif

//	Print "elapsed time = ",(StopMSTimer(-2) - t1)/1e6

	return(0)
End



// nothing to change here
//
//AAO version, uses XOP if available
// simply calls the original single point calculation with
// a wave assignment (this will behave nicely if given point ranges)
//
// Threaded Version
ThreadSafe Function SC_ParaCrystal_T(cw,yw,xw,p1,p2) : FitFunc
	Wave cw,yw,xw
	Variable p1,p2

//	Variable t1=StopMSTimer(-2)

#if exists("SC_ParaCrystalX")
	yw[p1,p2] = SC_ParaCrystalX(cw,xw)
#else
	yw[p1,p2] = fSC_ParaCrystal(cw,xw)		// shouldn't ever see this...
#endif

//	Print "elapsed time = ",(StopMSTimer(-2) - t1)/1e6

	return(0)
End








//
// unsmeared model calculation
//
Function fSC_ParaCrystal(w,x) : FitFunc
	Wave w
	Variable x
	
//	 Input (fitting) variables are not used
//	you would give them nice names
	Variable integral,loLim,upLim
	loLim = 0
	upLim = Pi/2
	
	Variable/G root:gDumY=0		//root:gDumX=0
	

	Variable scale,Dnn,gg,Rad,contrast,background,yy,latticeScale
	scale = w[0]
	Dnn = w[1] //Nearest neighbor distance A
	gg = w[2] //Paracrystal distortion factor
	Rad = w[3] //Sphere radius
	contrast = w[4] - w[5] //SLD contrast 
	background = w[6] 
		
// always calculate for type 0, SC
	latticeScale = (4/3)*pi*(Rad^3)/(Dnn^3) //Volume fraction calculated from lattice symmetry and sphere radius

	NVAR/Z nord=root:gNordSC
	if(NVAR_Exists(nord)!=1)
		nord=20
	endif
	
	integral = IntegrateFn_N(Integrand_SC_Outer,loLim,upLim,w,x,nord)
	
	
	integral *= SphereForm_SC(Rad,contrast,x)*scale*latticeScale
	//integral *= scale		//testing, returns Z(q) only

	integral += background	
	
	Return (integral)
	
End

// the outer integral is also an integral
Function Integrand_SC_Outer(w,x,dum)
	Wave w
	Variable x,dum
		
	NVAR yy = root:gDumY		
	yy = dum					// save the current dummy yy for use in the inner loop
	Variable retVal,loLim,upLim
	//
	loLim = 0
	upLim = Pi/2

	NVAR/Z nord=root:gNordSC
	if(NVAR_Exists(nord)!=1)
		nord=20
	endif
	
	retVal = IntegrateFn_N(Integrand_SC_Inner,loLim,upLim,w,x,nord)
	
	return(retVal)
End

//returns the value of the integrand of the inner integral
Function Integrand_SC_Inner(w,qq,dum)
	Wave w
	Variable qq,dum
	
	NVAR yy = root:gDumY		//use the yy value from the outer loop
	Variable xx,retVal
	xx = dum

	retVal = SC_Integrand(w,qq,xx,yy)
	
	return(retVal)
End

Function SC_Integrand(w,qq,xx,yy)
	Wave w
	Variable qq,xx,yy
	
	Variable retVal,temp1,temp2,temp3,temp4,temp5,aa,Da,Dnn,gg
	Dnn = w[1] //Nearest neighbor distance A
	gg = w[2] //Paracrystal distortion factor
	aa = Dnn
	Da = gg*aa
	
	temp1 = qq*qq*Da*Da
	temp2 = (1-exp(-1*temp1))^3
	temp3 = qq*aa
	temp4 = 2*exp(-0.5*temp1)
	temp5 = exp(-1*temp1)
	
	
	retVal = temp2*SCeval(xx,yy,temp3,temp4,temp5)
	retVal *= 2/pi
	
	return(retVal)
end

Function SCeval(Theta,Phi,temp3,temp4,temp5) //Function to calculate integrand values for simple cubic structure
	Variable Theta,Phi,temp3,temp4,temp5 //Phi and theta independent parts of the equation. These are passed to the funtion in order to take them off the loop and increase speed
	Variable temp6,temp7,temp8,temp9 //Theta and phi dependent parts of the equation
	Variable result
	
	temp6 = sin(Theta)
	temp7 = -1*temp3*sin(Theta)*cos(Phi)
	temp8 = temp3*sin(Theta)*sin(Phi)
	temp9 = temp3*cos(Theta)
	result = temp6/((1-temp4*cos((temp7))+temp5)*(1-temp4*cos((temp8))+temp5)*(1-temp4*cos((temp9))+temp5)) 
	
	return (result)
end

Function SphereForm_SC(radius,delrho,x)					
	Variable radius,delrho,x
	
	// variables are:							
	//[2] radius (�)
	//[3] delrho (�-2)
	//[4] background (cm-1)
	
	// calculates scale * f^2/Vol where f=Vol*3*delrho*(sin(qr)-qrcos(qr))/qr^3
	// and is rescaled to give [=] cm^-1
	
	Variable bes,f,vol,f2
	////handle q==0 separately
	If(x==0)
		f = 4/3*pi*radius^3*delrho*delrho*1e8
		return(f)
	Endif
	
	
	bes = 3*(sin(x*radius)-x*radius*cos(x*radius))/x^3/radius^3
	vol = 4*pi/3*radius^3
	f = vol*bes*delrho		// [=] �
	// normalize to single particle volume, convert to 1/cm
	f2 = f * f / vol * 1.0e8		// [=] 1/cm
	
	return (f2)	
	
End




///////////////////////////////////////////////////////////////
// smeared model calculation
//
Function SmearedSC_ParaCrystal(s) : FitFunc
	Struct ResSmearAAOStruct &s

//	the name of your unsmeared model (AAO) is the first argument
	Smear_Model_76(SC_ParaCrystal,s.coefW,s.xW,s.yW,s.resW)

	return(0)
End


/////////////////////////////////////////////////////////////////
//wrapper to calculate the smeared model as an AAO-Struct
// fills the struct and calls the ususal function with the STRUCT parameter
//
// used only for the dependency, not for fitting
//
Function fSmearedSC_ParaCrystal(coefW,yW,xW)
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
	err = SmearedSC_ParaCrystal(fs)
	
	return (0)
End