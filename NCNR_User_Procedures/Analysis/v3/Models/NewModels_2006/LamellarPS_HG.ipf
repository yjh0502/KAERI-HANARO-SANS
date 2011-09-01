#pragma rtGlobals=1		// Use modern global access method.

////////////////////////////////////////////////////
//
// model function that calculates the scattering from 
// lamellar surfactant structures. contrast includes the
// bilayer core, headgroups, and solvent. Integer numbers of 
// repeating bilayers (at a repeat spacing) leads to the
// familiar lamellar peaks. Bending constant information
// can be extracted from the Caille parameter with moderate
// success. A number of the parameters should be held
// fixed during the fitting procedure, as they should be well
// known:
//		repeat spacing D = 2*pi/Qo
//		contrast = calculated value
//		polydispersity should be close to 0.1-0.3
//   Caille parameter <0.8 or 1.0
//
// NOTES for Curve Fitting:
// the epsilon wave "epsilon_LamellarPS_HG" should be used to force a 
// larger derivative step for the # of repeat units, which is an integer.
// a singular matix error will always result if you don't follow this.
// Also, the # of repeats should be constrained to ~3<N<200, otherwise
// the optimization can pick a VERY large N, and waste lots of time
// in the summation loop
//
// instrumental resolution is taken into account in the REGULAR
// model calculation. resolution of ONLY the S(Q) peaks are 
// included. performing the typical smearing calculation would
// be "double smearing", so is not done.
//
// the delta Q parameter "gDelQ" or "dQ" is taken from the q-dependent
// instrument resolution "abssq" column as this is the identical definition
// as in the original reference. If the real resolution function cannot be
// found, a default value, typical of a "medium" q-range on the NG3 SANS is
// used, although the real values are highly preferred
//
// REFERENCE:	Nallet, Laversanne, and Roux, J. Phys. II France, 3, (1993) 487-502.
//		also in J. Phys. Chem. B, 105, (2001) 11081-11088.
//
// 14 JULY 2003 SRK
//
////////////////////////////////////////////////////

//this macro sets up all the necessary parameters and waves that are
//needed to calculate the model function.
//
Proc Plot_LamellarPS_HG(num,qmin,qmax)
	Variable num=128, qmin=.001, qmax=.5
	Prompt num "Enter number of data points for model: "
	Prompt qmin "Enter minimum q-value (A^1) for model: " 
	Prompt qmax "Enter maximum q-value (A^1) for model: "
//
	// constants
	Variable/G root:gEuler = 0.5772156649		// Euler's constant
	Variable/G root:gDelQ = 0.0025		//[=] 1/A, q-resolution, default value
	
	Make/O/D/n=(num) xwave_LamellarPS_HG, ywave_LamellarPS_HG
	xwave_LamellarPS_HG =  alog(log(qmin) + x*((log(qmax)-log(qmin))/num))
	Make/O/D coef_LamellarPS_HG = {1,40,10,2,0.4e-6,2e-6,6e-6,30,0.001,0.001}			//CH#2
	make/o/t parameters_LamellarPS_HG = {"Scale","Lamellar spacing, D (A)","Tail Thick (delT) (A)","HG Thick (delH) (A)","SLD of tails (A^-2)","SLD of HG (A^-2)","SLD of solvent (A^-2)","# of Lamellar plates","Caille parameter","Incoherent Bgd (cm-1)"}	//CH#3
	Edit parameters_LamellarPS_HG, coef_LamellarPS_HG
	ModifyTable width(parameters_LamellarPS_HG)=160
	ywave_LamellarPS_HG  := LamellarPS_HG(coef_LamellarPS_HG, xwave_LamellarPS_HG)
	Display ywave_LamellarPS_HG vs xwave_LamellarPS_HG
	ModifyGraph marker=29, msize=2, mode=4
	ModifyGraph log=1
	Label bottom "q (A\\S-1\\M) "
	Label left "I(q) (cm\\S-1\\M)"
	//
	// make epsilon wave appropriate for integer number of lamellar repeats
	Duplicate/O coef_LamellarPS_HG epsilon_LamellarPS_HG
	epsilon_LamellarPS_HG = 1e-4
	epsilon_LamellarPS_HG[7] = 1		//to make the derivative useful 
	AutoPositionWindow/M=1/R=$(WinName(0,1)) $WinName(0,2)
End

//
//this macro sets up all the necessary parameters and waves that are
//needed to calculate the  smeared model function.
//
//no input parameters are necessary, it MUST use the experimental q-values
// from the experimental data read in from an AVE/QSIG data file
////////////////////////////////////////////////////
//Proc PlotSmeared_LamellarPS_HG()								//Lamellar
//
//	// if no gQvals wave, data must not have been loaded => abort
//	If(ResolutionWavesMissing())		//part of GaussUtils
//		Abort
//	endif
//	
//	// constants
//	Variable/G root:gEuler = 0.5772156649		// Euler's constant
//	Variable/G root:gDelQ = 0.0025		//[=] 1/A, q-resolution, default value
//	// Setup parameter table for model function
//	Make/O/D smear_coef_LamellarPS_HG = {1,40,10,2,0.4e-6,2e-6,6e-6,30,0.001,0.001}		//CH#4
//	make/o/t smear_parameters_LamellarPS_HG = {"Scale","Lamellar spacing, D (A)","Bilayer Thick (delta) (A)","polydisp of Bilayer Thickness","contrast (A^-2)","# of Lamellar plates","Caille parameter","Incoherent Bgd (cm-1)"}
//	Edit smear_parameters_LamellarPS_HG,smear_coef_LamellarPS_HG					//display parameters in a table
//	
//	// output smeared intensity wave, dimensions are identical to experimental QSIG values
//	// make extra copy of experimental q-values for easy plotting
//	Duplicate/O $gQvals smeared_LamellarPS_HG,smeared_qvals				//
//	SetScale d,0,0,"1/cm",smeared_LamellarPS_HG							//
//
//	smeared_LamellarPS_HG := LamellarPS_HG_Smeared(smear_coef_LamellarPS_HG,$gQvals)		// SMEARED function name
//	Display smeared_LamellarPS_HG vs $gQvals									//
//	ModifyGraph log=1,marker=29,msize=2,mode=4
//	Label bottom "q (A\\S-1\\M)"
//	Label left "I(q) (cm\\S-1\\M)"
//
//End     // end macro 


//
Function LamellarPS_HG(w,x) : FitFunc
	Wave w
	Variable x
//	 Input (fitting) variables are:
//[0]Scale
//[1]repeat spacing, D
//[2]Tail Thickness (delT)
//[3]HG thickness (delH)
//[4]SLD tails
//[5]SLD HG
//[6]SLD solvent
//[7]# of Lam plates
//[8]Caille parameter
//[9]Incoherent Bgd (cm-1)
	
//	give them nice names
	Variable scale,dd,delT,delH,SLD_T,SLD_H,SLD_S,NN,Cp,bkg
	scale = w[0]
	dd = w[1]
	delT = w[2]
	delH = w[3]
	SLD_T = w[4]
	SLD_H = w[5]
	SLD_S = w[6]
	NN = trunc(w[7])		//be sure that NN is an integer
	Cp = w[8]
	bkg = w[9]
	
//	local variables
	Variable inten, qval,Pq,Sq,ii,alpha,temp,t1,t2,t3,dQ,drh,drt
	
	NVAR Euler = root:gEuler
	NVAR dQDefault = root:gDelQ
	//	x is the q-value for the calculation
	qval = x
	//get the instrument resolution
	SVAR/Z sigQ = gSig_Q
	SVAR/Z qStr = gQVals
	
	if(SVAR_Exists(sigQ) && SVAR_Exists(qStr))
		Wave/Z sigWave=$sigQ
		Wave/Z sig_Qwave = $qStr
		if(waveexists(sigWave)&&waveexists(sig_qwave))
			dQ = interp(qval, sig_Qwave, sigWave )
		else
			if(qval>0.01 && qval<0.012)
				print "using default resolution"
			endif
			dQ = dQDefault
		endif
	else
		dQ = dQDefault
	endif
	
	drh = SLD_H - SLD_S
//	drt = SLD_T - SLD_H		//original
	drt = SLD_T - SLD_S		//matches Lionel's changes in the Lamellar_HG model
	
	Pq = drh*(sin(qval*(delH+delT))-sin(qval*delT)) + drt*sin(qval*delT)
	Pq *= Pq
	Pq *= 4/(qval^2)
	
	ii=0
	Sq = 0
	for(ii=1;ii<(NN-1);ii+=1)
		temp = 0
		alpha = Cp/4/pi/pi*(ln(pi*ii) + Euler)
		t1 = 2*dQ*dQ*dd*dd*alpha
		t2 = 2*qval*qval*dd*dd*alpha
		t3 = dQ*dQ*dd*dd*ii*ii
		
		temp = 1-ii/NN
		temp *= cos(dd*qval*ii/(1+t1))
		temp *= exp(-1*(t2 + t3)/(2*(1+t1)) )
		temp /= sqrt(1+t1)
		
		Sq += temp
	endfor
	Sq *= 2
	Sq += 1
	
	inten = 2*Pi*scale*Pq*Sq/(dd*Qval^2)
	
	inten *= 1e8		// 1/A to 1/cm
	//inten = Sq
	Return (inten+bkg)
End

////the smeared model calculation
//Function LamellarPS_HG_Smeared(w,x) :FitFunc
//	Wave w
//	Variable x
//	
//	Variable ans
//	SVAR sq = gSig_Q
//	SVAR qb = gQ_bar
//	SVAR sh = gShadow
//	SVAR gQ = gQVals
//	
//	ans = Smear_Model_20(LamellarPS_HG,$sq,$qb,$sh,$gQ,w,x)	
//
//	return(ans)
//End	
