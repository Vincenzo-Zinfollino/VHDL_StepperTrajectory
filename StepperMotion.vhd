library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

ENTITY StepperMotion IS
    PORT( 	 
        clk            : IN  STD_LOGIC;
        THIS_PFM_OUT   : OUT STD_LOGIC;
		  FORCING_DIR_SW : IN STD_LOGIC;
		  DIR_SW         : IN  STD_LOGIC;		  
        DIR            : OUT STD_LOGIC	  
		  
    );
END StepperMotion;

ARCHITECTURE BEHAVE OF StepperMotion IS
    
	 
	 COMPONENT Frequency_Modulator IS 
        PORT( 
            clk : IN STD_LOGIC;
            ARR : IN INTEGER;				
            PFM_out : OUT STD_LOGIC
             );
    END COMPONENT;

    COMPONENT Stepper_Trajectory IS
	 
        GENERIC(         
            Prescaler_FSM      : INTEGER := 8334;
            TTC                : INTEGER := 16;            
            PRESCALER_ARR      : INTEGER := 50;
            CLOCK_FREQ_const   : INTEGER := 50000000;
            V_max              : INTEGER := 100; 
            A_max              : INTEGER := 10; 
            tc                 : INTEGER := 10  
               );

        PORT ( 
            clk              : IN  STD_LOGIC;
            h_out            : IN  INTEGER; -- distance           
				Step_count       : IN  INTEGER;
            ARR_out          : OUT INTEGER           
             );
    END COMPONENT;
	
	
 SIGNAL h   : INTEGER := 800; -- 800=90° 1600=180° 
 SIGNAL ARR : INTEGER :=   0;
 

 SIGNAL ARR_internal : INTEGER   := 0 ;
 SIGNAL PFM_internal : STD_LOGIC :='0';
 SIGNAL Count_step   : INTEGER   := 0 ; 
 
 SIGNAL Count_step_internal: INTEGER:= 0;
 
 SIGNAL Stop_PFM    : STD_LOGIC := '0';
 SIGNAL First_time  : STD_LOGIC := '1';
 
 -- Signals needed to choose direction
 SIGNAL DIR_internal: STD_LOGIC := '1'; 
 SIGNAL FORCED      : STD_logic := '0'; 
 SIGNAL CLOCKWISE   : STD_LOGIC := '0';
 
 
 BEGIN
 

  c1: Stepper_Trajectory  PORT MAP( clk, h, Count_step, ARR );
  c2: Frequency_Modulator PORT MAP( clk, ARR_internal,PFM_internal );
 

  Count_step   <= Count_step_internal;
  THIS_PFM_OUT <= PFM_internal;
  DIR <= DIR_internal;
  
	 
 PROCESS (clk,PFM_internal)
	 BEGIN 
	 
	 IF (count_step_internal >= 0) THEN
	 
	   ARR_internal<= ARR;
	 
	 ELSE 
	 
	   ARR_internal<= 0;
	 	 

	 END IF;
	
 END process;
	 
	 
	 
	 
  PROCESS (PFM_internal)
	 
	 BEGIN
	 
	  IF rising_edge(PFM_internal) THEN	 
		 
		 
				 IF (Count_step_internal> abs(h-1)) THEN
				 
					  Count_step_internal <= 0;
						 
					 IF ( FORCED = '1') THEN
						 
						 DIR_internal<= not DIR_internal;
						 
						 ElSIF (FORCED ='0')THEN
						 
							 IF (CLOCKWISE= '1') THEN
								
								 DIR_internal<= '1';
								
							 ELSE

								  DIR_internal<= '0';
								
							 END IF;

					  END IF;
						 
				 ELSE
		 
				    Count_step_internal <= Count_step_internal + 1;				 
		 
			
				 END IF;
				 
	   END IF;
	 
	END Process;

	
	
	
  Sel_Dir: PROCESS(clk)
	
	BEGIN
	  IF( FORCING_DIR_SW = '1' ) THEN
			
		 FORCED <= '1';
				
			
		ELSE
	
		  FORCED <='0' ;
			  
			 IF ( DIR_SW = '1') THEN
					
				 CLOCKWISE<= '1';
					
			 ELSE
					
				 CLOCKWISE<=  '0';
				
			 END IF;
						 

		END IF;
	END PROCESS;	
	 
	 
END BEHAVE;
