#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=1		// Use modern global access method.
//Modified from ImpedanceProfile4.0

//Sep282021
//Now "Long" recordings are gone. The idea is to keep the original data without changes, so it's easy to
//reanalyze without having to change waves' names.
//Now working waves are "V" for voltage and "I" for current while onda_v and onda_i are raw data


//April 19 2021
///////////////////////////////////////////////
//******READ ME***************
//Keep in mind that "onda" means wave in spanish
//Nom is the short of "nombre", which means "name" in spanish.
//That's why I use it as string to hold wave's name
//Both input waves have to be located in the Root or active folder

///////////////////////////////////////////////
Function Analyze(onda_v,onda_i,option)

wave onda_v //voltage in mV
wave onda_i //current in pA
variable option //theta=0; gamma=1

string nom1,nom2,nom3,nom4,nom5,nom6,nom7,nom8
variable i,rzap,dt

//DeletePoints 0,10000, onda_v //that way we start analysis with the beginning of the ZAP-stimulus (at 0.1s)
//DeletePoints 0,10000, onda_i

dt=deltax(onda_v)*1e3 //from sec to msec
nom1=nameofwave(onda_v)+"V"
nom2=nameofwave(onda_i)+"I"

//Change sep282021
duplicate/O/R=(0.12,10.12) onda_v $nom1 // Josephine: changed to 0-10 (1-16 before)
wave wVm=$nom1	
setscale/P x,0,deltax(wVm),"",wVm							//Jorge: changed to 0.12-10 to delete the begining of the voltage response to the change in baseline level

duplicate/O/R=(0.12,10.12) onda_i $nom2
wave wIm=$nom2
setscale/P x,0,deltax(wIm),"",wIm 


//////********************Display onda_V*****************************////

display/W=(0,30,270,230)/K=1 $nom1
Label left "\\u#2Membrane Voltage (mV)"
ModifyGraph grid(left)=2
ModifyGraph fSize=12

//Computing Rin with internal function
Rzap=rinzap(onda_v,onda_i)

//wave wresults=$"Resval"
//wresults[8]=rzap

//storing AVG Vm to be displayed on top plot
wavestats/Q/R=(0.12,10) onda_v
variable voltage=V_avg

TextBox/C/N=text1/X=0/Y=-8/F=0/A=MC "\\f01\\Z12V_avg="+num2str(voltage*1e3)+" mV"
TextBox/C/N=text2/X=0/Y=8/F=0/A=MC "\\f01\\Z12Rinzap="+num2str(rzap*1e-9)+" MΩ"

print "Average voltage response =",voltage*1e3," mV"
print "Rin zap =",rzap*1e-9," Ω"

//Calling more functions
ImpedanceProfile(wVm,wIm,dt,option)
DisplayWaves(wVm,option)



End

/////////////////////////////////////////////////////////////////////////////////////////////////////////

Function ImpedanceProfile(onda_V,onda_I,dt,option)

wave onda_V,onda_I
variable dt// delta time input waves
variable option //theta=0; gamma=1

string folder
string nom1,nom2,nom3,nom4,nom5,nom6,nom7,nom7a
string nom8,nom9,nom10,nom11,nom11a,nom12,nom12a,nom13,nom13a
variable deltaf 
variable i,j,k,npntsv,npntsi,restov,restoi

///////////////// making waves with even number of points, as required by FFT /////////////////////////////////

npntsv=numpnts(onda_V)
npntsi=numpnts(onda_I)

restov=mod(npntsv,2)
restoi=mod(npntsi,2)

if (restov != 0 )
	
	DeletePoints 0,1,onda_V
	
endif 

if (restoi != 0 )
	
	DeletePoints 0,1,onda_I
	
endif


/////////////////// Impedance MAGNITUDE //////////////////////////////
deltaf=1000/(dt*numpnts(onda_v)) //in Hz, according to the length and sampling of input wave. Read Igor manual on FFT

//Removing AVG value to clean FFT output
wavestats/Q onda_v
onda_v-=V_avg
variable savevmavg=V_avg

//Squared magnitude FFT
nom5="Vmag_FFT"
FFT/OUT=3/DEST=$nom5 onda_v
wave w5=$nom5
Setscale/P x,0,deltaf,"Hz",w5

//Removing AVG value to clean FFT output
wavestats/Q onda_I
onda_I-=V_avg

//FFT
nom6="Imag_FFT"
FFT/OUT=3/DEST=$nom6 onda_I
wave w6=$nom6
Setscale/P x,0,deltaf,"Hz",w6

//Creating impedance wave
nom7=nameofwave(onda_V)+"_Zap"
Duplicate/O $nom5 $nom7 //to have wave's structure
wave w7=$nom7
Setscale/P x,0,deltaf,"Hz",w7

w7=w5/w6*1e-6// scaling output to MΩ, 


//Cleaning output wave
if(option==0) //theta 0-5-15 Hz, oct 13 2021

	DeletePoints (15/deltax(w7)),(numpnts(w7)-15/deltax(w7)), w7
	DeletePoints 0,0.5/deltax(w7), w7
	setscale/P x,0.5,deltax(w7),"Hz",w7

endif


if(option==1)//gamma

	DeletePoints (100/deltax(w7)),(numpnts(w7)-100/deltax(w7)), w7
	DeletePoints 0,20/deltax(w7),w7
	setscale/P x,20,deltax(w7),"Hz",w7

endif

	
	nom7a=nom7+"n"
	duplicate/O $nom7 $nom7a
	wave w7a = $nom7a
	Smooth 4, w7a

Killwaves $nom5,$nom6

///////////////////  Phase lag //////////////////////////////

//Creating complex output waves
nom8="V_FFTcpx"
FFT/OUT=1/DEST=$nom8 onda_V
wave/C w8c=$nom8
Setscale/P x,0,deltaf,"Hz",w8c

nom9="I_FFTcpx"
FFT/OUT=1/DEST=$nom9 onda_I
wave/C w9c=$nom9
Setscale/P x,0,deltaf,"Hz",w9c

nom10="Impedance"

Duplicate/O $nom8 $nom10
wave/C w10c=$nom10
Setscale/P x,0,deltaf,"Hz",w10c

w10c=w8c/w9c

nom11=nameofwave(onda_v)+"_real"
make/O/N=(numpnts(onda_V)/2) $nom11
wave w11=$nom11
w11=real(w10c)*1e-6 //Scaling impedance output to MΩ
Setscale/P x,0,deltaf,"Hz",w11


nom12=nameofwave(onda_v)+"_imag"
make/O/N=(numpnts(onda_V)/2) $nom12
wave w12=$nom12
w12=imag(w10c)*-1e-6
Setscale/P x,0,deltaf,"Hz",w12

nom13=nameofwave(onda_V)+"_Phase"
make/O/N=(numpnts(w11)) $nom13
wave w13=$nom13
w13=(atan(w12/w11))*180/pi //scaling phase lag from radians to deegres
Setscale/P x,0,deltaf,"Hz",w13

//Cleaning output waves
//160 is the largest containing frequency. If changed by 20, it will contain up to 20 Hz
//Josephine: changed to 15-100 (2-160 before)

//real
if(option==1)//gamma 20-100

	DeletePoints (100/deltax(w11)),(numpnts(w11)-100/deltax(w11)), w11
	DeletePoints 0,20/deltax(w11), w11 //to remove first points containing low frequency noise and border artifact (was 0,2)
	setscale/P x,20,deltax(w11),"Hz",w11 

endif

if(option==0)//theta 0.5-15 oct 13 2021

	DeletePoints (15/deltax(w11)),(numpnts(w11)-15/deltax(w11)), w11
	DeletePoints 0,0.5/deltax(w11), w11 //to remove first points containing low frequency noise and border artifact (was 0,2)
	setscale/P x,0.5,deltax(w11),"Hz",w11 

endif

nom11a=nom11+"n"
duplicate/O $nom11 $nom11a
wave w11a = $nom11a
Smooth 4, w11a

//imag
if(option==1)//gamma

	DeletePoints (100/deltax(w12)),(numpnts(w12)-100/deltax(w12)), w12
	DeletePoints 0,20/deltax(w12), w12
	setscale/P x,20,deltax(w12),"Hz",w12

endif

if(option==0)//theta

	DeletePoints (15/deltax(w12)),(numpnts(w12)-15/deltax(w12)), w12
	DeletePoints 0,0.5/deltax(w12), w12
	setscale/P x,0.5,deltax(w12),"Hz",w12

endif


nom12a=nom12+"n"
duplicate/O $nom12 $nom12a
wave w12a = $nom12a
Smooth 4, w12a


//Phase

if(option==1)//gamma

	DeletePoints (100/deltax(w13)),(numpnts(w13)-100/deltax(w13)), w13
	DeletePoints 0,20/deltax(w13), w13
	setscale/P x,20,deltax(w13),"Hz",w13

endif

if(option==0)//theta

	DeletePoints (15/deltax(w13)),(numpnts(w13)-15/deltax(w13)), w13
	DeletePoints 0,0.5/deltax(w13), w13
	setscale/P x,0.5,deltax(w13),"Hz",w13

endif

nom13a=nom13+"n"
duplicate/O $nom13 $nom13a
wave w13a = $nom13a
Smooth 4, w13a

Killwaves w8c,w9c,w10c

//Adding AVG value to recover original wave
onda_v+=savevmavg

End Function

////////////////////////////////////////////////////////////////////////////////////////////////////
//This function has a lot of commented text to inactivate operations that compute the value of different parameter
//once we know what we want to measure we will activate them
Function DisplayWaves(ondav,option)

wave ondav
variable option //0=theta;1=gamma

string name1,name2,name3,name4,name5,name6,name7,name8
variable i,j,k

//Fitting variable for ZAP curve theta condition (set at 0.5 or 1 Hz)
variable startfitting
startfitting=0.5

//////Display ZAP///////////////////////////////
name1=nameofwave(ondav)+"_zap"
name2=name1+"n"
wave wZap=$name1
wave wZapn=$name2

display/W=(275,30,545,230)/K=1 wZap,wZapn

if(option==0)//theta
	
	SetAxis bottom 0,16
	
endif

if(option==1)//gamma	

	SetAxis bottom 20,100 //20-100, to evaluate peak, Berechnung mit 20 Hz!

endif

Label left "\u#2Impedance"
label bottom "Frequency (Hz)"
ModifyGraph lsize=2
ModifyGraph mode($name2)=2,rgb($name2)=(0,0,0)
ModifyGraph fSize=12

//Polinomial fit
if(option==0)//theta

//	wavestats/Q/R=(0,3) $name1
	CurveFit/Q/NTHR=0 poly 5,  wZapn(startfitting,12) /D // Cambio inicio del fit de V_minloc a 0.5 
	name3="fit_"+name2
	wave w3=$name3
	ModifyGraph rgb($name3)=(65535,65535,0)

endif

if(option==1)//gamma

//	wavestats/Q/R=(0,3) $name1
	CurveFit/Q/NTHR=0 poly 5,  wZapn(20,100) /D //  was 20,80
	name3="fit_"+name2
	wave w3=$name3
	ModifyGraph rgb($name3)=(65535,65535,0)
	
endif

//Min and Max impedance waves
string minwave=name1+"_min"
string maxwave=name1+"_max"

if(option==0)//theta
	
//	wavestats/Q/R=(0,3) $name1
	Make/O/N=50 $minwave
	wave wmin=$minwave
	setscale/I x 0,15,"",wmin
	wmin=w3[0]
	
endif

if(option==1)//gamma
	
	wavestats/Q/R=(20,50) $name1
	Make/O/N=50 $minwave
	wave wmin=$minwave
	setscale/I x 20,100,"",wmin
	wmin=w3[0]
	
endif


appendtograph $minwave
ModifyGraph rgb($minwave)=(0,0,0)
ModifyGraph lstyle($minwave)=3

if(option==0)//theta

	wavestats/Q/R=(0.5,15) wZapn //statistic to smooth impedance trace; default: 0.5-15
	duplicate/O wmin $maxwave
	wave wmax=$maxwave
	setscale/I x 0,15,"",wmax

endif

if(option==1)//gamma

	wavestats/Q/R=(20,80) wZapn //statistic to smooth impedance trace; default: 0.5-15
	duplicate/O wmin $maxwave
	wave wmax=$maxwave
	setscale/I x 20,100,"",wmax

endif

wavestats/Q w3 //fitted curve
variable res_frec=V_maxloc
variable zmax=V_max
variable q_coef

wmax=V_max
zmax=V_max
q_coef=V_max/w3(0.5) // default: 0.5

appendtograph $maxwave
ModifyGraph rgb($maxwave)=(0,0,0)
ModifyGraph lstyle($maxwave)=3
//SetAxis left 0,(V_max+10)

TextBox/C/N=text0/X=0/Y=0/F=0/A=RT "\\f01\\Z12Q="+num2str(q_coef)
TextBox/C/N=text1/X=0/Y=15/F=0/A=LB "\\f01\\Z12F="+num2str(res_frec)+" Hz"
TextBox/C/N=text2/X=0/Y=0/F=0/A=LB "\\f01\\Z12Zmax="+num2str(Zmax)+" MΩ"

Print "Impedance coef. (Q)= ",q_coef
Print "Resonant Frequency= ",res_frec," Hz"
Print "Z max= ",Zmax," Ω"

//Saving resonant values
//wavestats/Q ondav
//
//wave wresults=$"Resval"
//
//wresults[0]=V_avg
//wresults[1]=zmax
//wresults[2]=res_frec
//wresults[3]=q_coef
//end saving

//////////////////Display Phase lag////////////////////////////////

name4=nameofwave(ondav)+"_Phase"
name5=name4+"n"

display/W=(550,30,820,230)/K=0 $name4,$name5

if(option==0)//theta

	SetAxis bottom 0.5,15

endif

if(option==1)//gamma

	SetAxis bottom 15,100

endif


//SetAxis left 10,-70
label left "Phase lag (Deg)"
label bottom "Frequency (Hz)"
ModifyGraph lsize=2
ModifyGraph zero(left)=3
ModifyGraph mode($name5)=2,rgb($name5)=(0,0,0)
ModifyGraph fSize=12

//Obtaining phase values
//wave w13=$name4
//
//wavestats/Q/R=(0,10) w13
//	
//	if(V_max >= 0)
//	
//		wresults[6]=V_max
//		wresults[7]=V_maxloc		
//		
//	else
//	
//		wresults[6]=0
//		wresults[7]=0.5
//		
//	endif
//	
//wresults[4]=w13(res_frec)
//wresults[5]=w13(6)

//end saving

//////////////////Display Complex impedance ////////////////////////////////
name7=nameofwave(ondav)+"_realn" //smoothed waves
name8=nameofwave(ondav)+"_imagn"

display/W=(825,30,1100,230)/K=1 $name8 vs $name7
label left "Z Imag (MΩ)"
label bottom "Z Real (MΩ)"
ModifyGraph mode=3,marker=19
ModifyGraph zero(left)=3
ModifyGraph fSize=12

end

//////////////***************************//////////////////
//Supposing a squared pulse from 10.5 to 10.7 sec
//Josephine: squared pulse in our PGF from 10.3 to 10.6 sec
Function Rinzap(onda_v,onda_i)

wave onda_v// in mV
wave onda_i// in pA

string nom1,nom2,nom3
variable ipulse,deltav,rzap,v1,v2,i1,i2

wavestats/Q/R=(10.2,10.3) onda_v 
v1=V_avg
wavestats/Q/R=(10.5,10.6) onda_v
v2=V_avg
deltav=v2-v1


wavestats/Q/R=(10.2,10.3) onda_i
i1=V_avg
wavestats/Q/R=(10.5,10.6) onda_i
i2=V_avg
ipulse=i2-i1

print "Amplitud ZAP=",ipulse*1e12," pA"

rzap=(deltav/ipulse)*1e3 //in MΩ

return rzap

end

/////////****************************//////////////////////
