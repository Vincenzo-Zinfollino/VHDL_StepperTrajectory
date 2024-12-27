 library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all; -- test 
use ieee.std_logic_unsigned.all;

ENTITY Stepper_Trajectory is

	GENERIC( 			
				
				Prescaler_FSM :INTEGER := 8334 ; -- FPGA base clock is 50 MHz this factor divide  the clock to  more or less 6 KHz, used for the PFM state machine 
				TTC:INTEGER := 16; -- 16*10^-5 *10^5  conversion rate used for pass from time to counter value 
								
				PRESCALER_ARR    : INTEGER := 50;-- 50MHZ/1 MHz -> FPGAclock/ MAXmicrostep_over_second  1MHz < 6MHz (Max Freequency of the stepper driver  )
				CLOCK_FREQ_const : INTEGER := 50000000;
				
				V_max : INTEGER:= 100 ; -- microstep/s V_max=1,785 rpm 
				A_max : INTEGER:= 10 ;  -- microstep/s^2  A_max=  rad/s^2 
				
				tc    : INTEGER := 10   -- V_max/A_max 			
				
	);


  PORT ( clk        : IN  STD_LOGIC;
			h_out      : IN  INTEGER;
			Step_count : IN  INTEGER;			
			ARR_out    : OUT INTEGER			
			 
			 );
  END Stepper_Trajectory;
  
  
  ARCHITECTURE BEHAVE OF Stepper_Trajectory IS
  
  SIGNAL Clock_PFM : STD_LOGIC:='0'; -- Clock for the frequency modulation process 
  SIGNAL Clock_FSM : STD_LOGIC:='0'; -- Clock for the counter of the Finite state machine 
  
  
  SIGNAL Count_PFM : INTEGER := 0;
  SIGNAL Count_FSM : INTEGER := 0;
  
  SIGNAL ARR : INTEGER   :=  0 ;
  SIGNAL DIR : STD_LOGIC := '0';  
  
  SIGNAL v: INTEGER := 0;
  SIGNAL a: INTEGER := 0;
    
  -- COUNTERS:
  
  SIGNAL ctf: INTEGER :=0; -- counter timer final: it reprents the final time with counts 
   
  SIGNAL Timer_trajectory     : INTEGER := 0;   -- counters for trajectory that increases with each TTC
  SIGNAL Timer_trajectory_old : INTEGER := 0;
  
  SIGNAL count_acc_part:   INTEGER   :=0;   -- counts required for the acceleration part
  SIGNAL count_const_part: INTEGER   :=0;   -- counts required for the constant velocity part 
  SIGNAL count_dec_part:   INTEGER   :=0;   -- counts required for the deceleration part
  
  --FSM Signal Declaration
  
  SIGNAL data_in: STD_LOGIC:='0';
  
  TYPE   state_values IS (HOLD, ACCELLERATION, CONSTANT_VELOCITY, DECELLERATION);
  
  SIGNAL pres_state, next_state : state_values;
  
  SIGNAL Sel_State   : STD_LOGIC_VECTOR( 1 downto 0) := "00" ; 

  
  BEGIN
  
  -----------------------------------------------------------------------------------------------------
  -- SI PUO' TOGLIERE
  
  ClockDivider_PFM: PROCESS (clk) 
  
  BEGIN
  
		 IF (rising_edge(clk)) THEN
		 
		   Count_PFM<=Count_PFM+1; 
		 
				IF ( Count_PFM = ( PRESCALER_ARR -1   )) THEN
					
							Clock_PFM <= not Clock_PFM;
							
							Count_PFM<=0;
		  
				END IF;		   		
		      
		  END IF;
  
  
  END PROCESS;
  ----------------------------------------------------------------------------------------------------
  
  ClockDivider_FSM: PROCESS (clk) 
  
  BEGIN

		 IF (RISING_EDGE(clk)) THEN
		 
		   Count_FSM<=Count_FSM+1; 
		 
				IF ( Count_FSM = ( Prescaler_FSM -1 )) THEN
					
							Clock_FSM <= NOT Clock_FSM;
							
							Count_FSM <= 0;
		  
				 END IF;
		      
		 END IF;
  
  
  END PROCESS;
  
  
  Sel_Dir: PROCESS(h_out)	
  
	BEGIN
			IF(h_out > 0) THEN
			
				DIR <= '1';
				
			ELSE
			
				DIR <= '0';
		
			END IF;
			
	END PROCESS;
  
  
  
  TimeCalculation: PROCESS (clk) 
  
   BEGIN
  
   IF (rising_edge(clk)) THEN
		
		ctf <= ((((h_out)*100000)/(V_max)) + tc*100000)/TTC;
		
		 -- I don't multitply to 100000 at the end as before, because i multiply for 100000 the two terms. This is the same
		 -- ,but it is necessary because if the difference of the positions is smaller the V_max at the denominator we 
		 -- have a comma number whith 0 as first number, so VHDL truncates to 0.
		 
		 -- We have a small error between the ctf calculated on matlab and the ctf calculated on VHDL. 
		 -- This error is due to the roundings but we have estimated that is less than 3 ms. 
		
	
		-- (h/V_max) = (tf - tc)
		-- V_max/A_max = tc
		
		-- We use V_max/A_max = tc = constant everytime because we change only the constant part. This is an our choice to 
		-- semplify the scalation trajectory.
		
		-- we used these factor multiplier( 10,100 and 1000) to avoid the comma in the numbers .		
		
		
	
	  IF (tc*10000/TTC) > (ctf/2) THEN  -- tc*1000 to avoid comma numbers 
	  
	  -- TRAINGULAR VELOCITY TRAJECTOR
		
		v <= (ctf/2)*A_max; -- v=ctf/2*a because this is the case of triangular wave, so v=t*a_max so t is t=tf/2
		
	  
		count_acc_part   <= (ctf/2);
		count_const_part <= count_acc_part+1 ;
		count_dec_part   <= 2* count_acc_part-1; 

	   	
	 ELSE
	 -- TRAPEIZODAL VELOCITY TRAJECTOR

		 count_acc_part   <= tc*10000/TTC;
		 count_const_part <= ctf - count_acc_part;
		 count_dec_part   <= ctf;
		 
		 v <= V_max;
		 
		 
	 END IF;
	
   END IF;
  
  END PROCESS;  
  

  
  CounterFSM: PROCESS(Clock_FSM)
  
  BEGIN
  
  IF (rising_edge(Clock_FSM))THEN
  
  
  IF (Step_count*ctf/h_out= 0)THEN 
  
	  Timer_trajectory     <= Timer_trajectory + 1;
	  Timer_trajectory_old <= Timer_trajectory;
  
  
  ELSIF (Step_count*ctf/(h_out+1)> 0) THEN   -- h_out+1 is necessary in the change of the state at the end of the trajectory. without it
                                               -- the chage doesn't happen.
   
	  Timer_trajectory <= Timer_trajectory_old+((Step_count*ctf)/(h_out+1)); 
	  Timer_trajectory_old <= 0;
	 
  END IF;
  
  -- Saturation Timer_trajectory
  IF ( Timer_trajectory > ctf) AND (Step_count=(h_out-1)) THEN 
	  Timer_trajectory <= 0;
  
  ELSIF ( Timer_trajectory > ctf) AND (Step_count=h_out) THEN 
		Timer_trajectory <= 0;
 
  ELSIF ( Timer_trajectory > ctf) THEN
  
		Timer_trajectory <= ctf;
  END IF;
  

  data_in<='0';
  
    IF ( ((Timer_trajectory > 0) AND (Timer_trajectory <=  count_acc_part)) ) THEN
	 
		IF (Sel_State= "00") THEN
		
		 data_in <='1';
		 Sel_State <= "01";
	  
	  END IF;
	

	  ELSIF ( ((Timer_trajectory> count_acc_part) AND (Timer_trajectory <= count_const_part)) ) THEN
	  
		IF ((Sel_State = "01") ) THEN
		
		   data_in <='1';
		   Sel_State <= "11";
		 
	  END IF;
	  
    ELSIF (  ((Timer_trajectory> (count_const_part+1)) AND (Timer_trajectory  <= count_dec_part-1 )))  THEN
		
		IF  (Sel_State = "11") THEN
		
			data_in <= '1';
			Sel_State <= "00";
			
		END IF;
		
		
    ELSIF ((Timer_trajectory > (count_dec_part-1)) ) THEN 
	  
			data_in   <= '1';
			Sel_State <= "00";
			Timer_trajectory <= 0;
 
	 END IF;
  
 END IF;
  
  
 END PROCESS;
  
  
  
 statereg:PROCESS(Clock_FSM)
	  BEGIN 
	  	  IF RISING_EDGE(Clock_FSM)   THEN
			  pres_state <= next_state;
		  END IF;
		  
 END PROCESS statereg;
  
 
  
  
  
	FSM:PROCESS(pres_state,data_in)
	
	  BEGIN
	    CASE pres_state IS
		 
			WHEN HOLD => 
		      CASE data_in IS
			      WHEN '0'    => next_state <= HOLD;
					WHEN '1'    => next_state <= ACCELLERATION;
					WHEN OTHERS => next_state <= HOLD;
			   END CASE;
				
		    WHEN ACCELLERATION => 
			   CASE data_in IS
		         WHEN '0'    => next_state <= ACCELLERATION;
			      WHEN '1'    => next_state <= CONSTANT_VELOCITY;
			      WHEN OTHERS => next_state <= ACCELLERATION;
		      END CASE;
				
			WHEN CONSTANT_VELOCITY => 
			   CASE data_in IS
				   WHEN '0'    => next_state <= CONSTANT_VELOCITY;
					WHEN '1'    => next_state <= DECELLERATION;
				   WHEN OTHERS => next_state <= CONSTANT_VELOCITY;
				END CASE;
			
		   WHEN DECELLERATION => 
		      CASE data_in IS
			      WHEN '0'    => next_state <= DECELLERATION;
					WHEN '1'    => next_state <= HOLD;
					WHEN OTHERS => next_state <= DECELLERATION;
				END CASE;

			WHEN OTHERS => next_state <= HOLD;
		END CASE;
		
	END PROCESS FSM;
	  
	  
  
   outputs:PROCESS(pres_state,data_in,Timer_trajectory)
	  BEGIN
	    CASE pres_state IS
		 
		    WHEN HOLD =>
			   IF data_in ='0' THEN 
				
					ARR <= 0;
					
				END IF;
				
				
			 WHEN ACCELLERATION => 
			   IF data_in = '0' THEN
					
					IF (A_max*Timer_trajectory = 0) THEN 
					
					  ARR <= 0;
					
					ELSE					
 
					  ARR <= (CLOCK_FREQ_const/PRESCALER_ARR)*1000/((A_max/10)*Timer_trajectory*TTC); 					
			
					END IF;						
					
				END IF;
				
				
			 WHEN CONSTANT_VELOCITY =>
			   IF data_in = '0' THEN
					
					ARR <= (CLOCK_FREQ_const/PRESCALER_ARR)/v;
					
				END IF;
				
			  WHEN DECELLERATION =>
			   IF data_in = '0' THEN
					
					IF ( Timer_trajectory > (ctf-1)) THEN
					  ARR <= 60000;
					 
					ELSE
					
					  ARR <= (CLOCK_FREQ_const/PRESCALER_ARR)*1000/(ctf*(A_max/10)*TTC-(A_max/10)*TTC*Timer_trajectory);
					
					END IF;
					
				END IF;			 
			 
			 WHEN OTHERS => 
			 
					 ARR <= 0; -- If we don't Know the status in the indecision DO NOTHING !
					
			 END CASE; 			  	 
			
			 
	END PROCESS outputs;		  
		  
	PROCESS (clk) 
	  BEGIN 
		  
		  IF ( ARR > 60000) THEN -- Saturation of the ARR
		  
			ARR_out <= 60000;
		  
		  ELSE 		  
		  
			ARR_out<=ARR;
		  
		  
		  END IF;		  
		 
		 
	 END PROCESS ;
  
  END BEHAVE;
  
  
  