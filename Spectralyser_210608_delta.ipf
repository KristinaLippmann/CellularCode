#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Some functions for calculating gamma and theta power spectra (PS) in Patchmaster traces
// JE, 2021_01_26, Version 1
// V 2.1, 2021_02_08, corrected the wrong removal of the DC component, which was done without 
// correcting the x-scaling. And labeled output as PSD, i.e. in mV^2/Hz
// MB210528: the only thing I've changed is that now, the software automatically calculates the avg Vm within 
// the borders you set via the cursors and the peak frquency of the PSD wave. Both are saved in the clipboard.
// JK210608: delta power added (1-3 Hz)

constant k_SP_timespan	= 1 	// (s) time window for calculating the PSD
constant k_f_lo  		= 1		// (Hz), lower freq. of PSD
constant k_f_hi 			= 140	// (Hz), upper freq. of PSD

constant k_d_lo  			= 1		// (Hz), lower freq. of delta
constant k_d_hi  			= 3		// (Hz), upper freq. of delta
constant k_t_lo  			= 3		// (Hz), lower freq. of theta
constant k_t_hi  			= 8		// (Hz), upper freq. of theta
constant k_g_lo  			= 30	// (Hz), lower freq. of gamma
constant k_g_hi  			= 100	// (Hz), upper freq. of gamma
constant k_sg_lo  			= 30	// (Hz), lower freq. of gamma
constant k_sg_hi  			= 50	// (Hz), upper freq. of gamma
constant k_mg_lo  			= 50	// (Hz), lower freq. of gamma
constant k_mg_hi  			= 90	// (Hz), upper freq. of gamma
constant k_eg_lo  			= 90	// (Hz), lower freq. of gamma
constant k_eg_hi  			= 140	// (Hz), upper freq. of gamma

// Make our functions available through the "Macros" menu
Menu "Macros"
	Submenu "Power Spectral Density"
		"Add controls to graph", PS_AddControlls()
	End
End

// This function just adds the controls to the top graph
Function PS_AddControlls()
	ControlBar  40
	ShowInfo
	Button PS_PlaceB size={170,20}, title="Place cursor B 1s after A",proc=PS_PlaceB
	Button PS_calcPS size={170,20}, title="Calculate PSD",            proc=PS_calcPSD
	TitleBox PS_ShowVersion         title="Version 2.1",disable=2,frame=0,fstyle=1
end

// This is the main function that calculates the Power spectral density
Function PS_calcPSD(ctrlName) : ButtonControl
	String ctrlName
	String   InfoOnA,  InfoOnB, strTheWave, MyLabel
	Variable multTime, p0, p1, x0, x1, xTolerance

	// Retrieve information on cursors and do some checks
	InfoOnA = CsrInfo(A)
	InfoOnB = CsrInfo(B)
	PS_TestCursor(InfoOnA, "A")
	PS_TestCursor(InfoOnB, "B")

	// OK, we do have valid cursors. Where do they sit?
	strTheWave	= StringbyKey("TNAME", InfoOnA)		// Name of Wave
	if(0 != cmpstr(strTheWave, StringbyKey("TNAME", InfoOnB)))
		Abort "Cursors must sit on the same trace.\rI stop here, no harm done..."
	endif
	Wave TheWave	= $strTheWave							// Reference to the wave
    
	// Check for correct (1s) timing
	p0 = NumberByKey("POINT", InfoOnA)	
	p1 = NumberByKey("POINT", InfoOnB)
	x0 = pnt2x(TheWave,p0)	
	x1 = pnt2x(TheWave,p1)
	multTime		= PS_TestWaveUnit(TheWave)	// '1' for 's', '1000' for 'ms'
   xTolerance	= DimDelta(TheWave,0) / 10	// to correct for float point problems in x-scaling    

	If( abs(k_SP_timespan - ((x1-x0) / multTime)) > xTolerance )
		Abort "Incorrect timing of cursors.\rI stop here, no harm done..."
	endif
	
	// The FFT-based DSPPeriodogram needs an even number of points
	if( (p1-p0)/2 == round (p1-p0)/2 ) // odd number of points
		p1 --									// now we do have an even number..
	endif

	// Pick our data
	Duplicate /O/FREE/R=[(p0),(p1)] TheWave tmpDat
	Wavestats /Q/R=[p0,p1] TheWave
	Variable Vm_avg = V_avg
		Printf "The mean Vm is %g V\r", Vm_avg
	
	// Assure/set 's' scaling
	strswitch(WaveUnits(tmpDat, 0))
		case "s":	
			// ok, nothing needs to be done
			break
		case "":	
			Beep
			Print "Data had no time unit, we took 's' for granted..."
			SetScale/P x 0,DimDelta(tmpDat,0),"s", tmpDat
			break
		case "ms":	
			Print "For the analysis, the time unit was changed to 's'..."
			SetScale/P x 0,DimDelta(tmpDat,0)/1000,"s", tmpDat
			break
		default:
			Abort "The wave unit should be 's' or 'ms'.\rI stop here, no harm done..."
	endswitch
	
	// Assure/set 'mV' scaling (in order to get the unit mV^2...)
	strswitch(WaveUnits(tmpDat, -1))
		case "V":	
			Print "For the analysis, the y unit was changed to 'mV'..."
			tmpDat *= 1000
			SetScale d 0,0,"mV", tmpDat
			break
		case "":	
			Beep
			Print "Data had no y unit, we took 'V' for granted and changed to mV..."
			tmpDat /= 1000
			SetScale d 0,0,"mV", tmpDat
			break
		case "mV":	
			// ok, nothing needs to be done
			break
		default:
			Abort "The y unit should be 'V' or 'mV'.\rI stop here, no harm done..."
	endswitch
	
	// OK, do the PSD
	// see https://www.wavemetrics.com/products/igorpro/dataanalysis/signalprocessing/powerspectra
	DSPPeriodogram/DTRD  tmpDat

	Wave Per=W_Periodogram
	Per /= p1-p0						// normalization of the window function, for rect. it is 1^2 with p1-p0 points
	Per *= 2							// mirroring negative frequencies
	SetScale d 0,0,"[mV\S2\M/Hz]", Per  // see https://pure.mpg.de/pubman/faces/ViewItemOverviewPage.jsp?itemId=item_152164

	// Limit to the frequency window of interest
	DeletePoints x2pnt(Per,k_f_hi)+1,inf, Per			// cut upper frequencies
	DeletePoints 0,x2pnt(Per,k_f_lo),     Per			// cut lower frequencies
		SetScale/P x k_f_lo,DimDelta(Per,0),"Hz", Per	// adjust the scaling

	// Create a uniquely-named copy to be remembered
	MyLabel = "PS_"+strTheWave
	Duplicate /O Per $MyLabel
	KillWaves  Per
	Wave Per=$"PS_"+strTheWave
		
	Variable Per_Max=CalcPeakFreq(Per, strTheWave)
//	Wave FitPer=$"fit_PS_"+strTheWave

	
	// Plot it using a uniquely-named graph
	Dowindow /K $"Plot_"+MyLabel
	Display/K=1 Per as MyLabel
//	AppendtoGraph $"fit_PS_"+strTheWave
	Dowindow /C $"Plot_"+MyLabel
	SetAxis/A/N=0/E=0 bottom
	SetAxis/A/N=1/E=1 left
	Label left   "power spectral density \r\\u"
	Label bottom "frequency [\\U]"
	
	// Report theta and gamma power
	
	Report1(Per, Vm_avg, Per_Max)
end

function Report1(Per, Vm_avg, Per_Max)
	Wave Per
	Variable Vm_avg, Per_Max
	Variable dP, tP, gP, sgP, mgP, egP, tP2P, gP2P
	dP = area(Per, k_d_lo, k_d_hi)
	tP = area(Per, k_t_lo, k_t_hi)
	gP = area(Per,k_g_lo,k_g_hi)
	sgP = area(Per,k_sg_lo,k_sg_hi)
	mgP = area(Per,k_mg_lo,k_mg_hi)
	egP = area(Per,k_eg_lo,k_eg_hi)
	tP2P = 2*sqrt(tP*2)		// '2*' because we go for p2p, not ampl.
	gP2P = 2*sqrt(gP*2)
	Printf "Delta power (%g- %g Hz) %.2g mV^2/Hz\r", k_d_lo,k_d_hi,dP 
	Printf "Theta power (%g- %g Hz) %.2g mV^2/Hz,\t i.e. mean peak2peak %.2g mV\r", k_t_lo,k_t_hi,tP, tP2P
	Printf "Gamma power (%g- %g Hz) %.2g mV^2/Hz,\t i.e. mean peak2peak %.2g mV\r", k_g_lo,k_g_hi,gP, gP2P
	Printf "Slow gamma power (%g- %g Hz) %.2g mV^2/Hz\r", k_sg_lo,k_sg_hi,sgP
	Printf "Mid gamma power (%g- %g Hz) %.2g mV^2/Hz\r", k_mg_lo,k_mg_hi,mgP
	Printf "Eps gamma power (%g- %g Hz) %.2g mV^2/Hz\r", k_eg_lo,k_eg_hi,egP
	PutScrapText num2str(Vm_avg)+"\t"+num2str(Per_Max)+"\t"+num2str(dP)+"\t"+num2str(tP)+"\t"+num2str(gP)+"\t"+num2str(sgP)+"\t"+num2str(mgP)+"\t"+num2str(egP)
	Print  "Power values are in the clipboard..."
end

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// This function places cursor B 1s (k_SP_timespan) after cursor A
// JE, 2021_01_23
Function PS_PlaceB(ctrlName) : ButtonControl
	String ctrlName
	String   InfoOnA,  strTheWave
	Variable Target4B, multTime
	
	// Retrieve information on cursor A and do some checks
	InfoOnA = CsrInfo(A)
	PS_TestCursor(InfoOnA, "A")
	
	// OK, we do have a valid cursor. Where does it sit?
	strTheWave	= StringbyKey("TNAME", InfoOnA)		// Name of Wave
	Wave TheWave	= $strTheWave							// Reference to the wave
	
	// The timing
	multTime = PS_TestWaveUnit(TheWave)			// '1' for 's', '1000' for 'ms'
	
	// Check for long enough data
	Target4B	= pnt2x(TheWave,NumberByKey("POINT", InfoOnA)	)		// A per x
	Target4B	= Target4B + k_SP_timespan * multTime						// B per x
	Target4B	= x2pnt(TheWave,Target4B)									// B per point
 	If(Target4B>= Dimsize(TheWave,0))
		Abort "Not enough points after A.\rI stop here, no harm done..."
	endif
	// Place the cursor
	Cursor /P B  $strTheWave  Target4B
	// Done
End
//------------------------------------------------------------------
  
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Small helpers, JE, 2021_01_23
// Do some tests on the cursor info
static Function PS_TestCursor(strInfo, WichOne)
	string  strInfo, WichOne		// e.g. CsrInfo(A), "A"
	if(strlen(strInfo) == 0)
		Abort "Cursor "+WichOne+" is not on graph.\rI stop here, no harm done..."
	endif
	if(NumberByKey("ISFREE", strInfo) == 1)
		Abort "Cursor "+WichOne+" must not be free but on a trace.\rI stop here, no harm done..."
	endif
End

// Test the wave unit and return the time-multiplicator
static Function PS_TestWaveUnit(w)
	Wave w
	strswitch(WaveUnits(w, 0))
		case "s":	
			return 1
			break
		case "ms":	
			return 1000
			break
		default:
			Abort "The wave unit should be 's' or 'ms'.\rI stop here, no harm done..."
	endswitch
End
//------------------------------------------------------------------

//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// helper to fit the Periodogram and calculate the maximum (peak frequency) 
static Function CalcPeakFreq(Per, strTheWave)
	Wave Per
	String strTheWave

//	CurveFit /Q lor, Per /D
//		String strFitPer="fit_PS_"+strTheWave
//		Wave FitPer=$strFitPer
	
	WaveStats /Q Per
		Variable Per_Max=V_maxloc
		Printf "The peak frequency is %g Hz\r", Per_Max

	Return Per_Max
End 




//    E O F