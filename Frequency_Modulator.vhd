library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

ENTITY Frequency_Modulator is 
	PORT( clk     : IN STD_LOGIC;
			ARR     : IN INTEGER;			
			PFM_out : OUT STD_LOGIC			
		
      	);

END Frequency_Modulator;


ARCHITECTURE PFM_GEN OF Frequency_Modulator IS

 SIGNAL counter_val   : INTEGER   :=  0 ;  
 SIGNAL COUNT_t       : INTEGER   :=  0 ;
 SIGNAL PRESCALER_ARR : INTEGER   := 50 ;
 SIGNAL Clock_PFM     : STD_LOGIC := '0';
 SIGNAL Count_PFM     : INTEGER   :=  0 ;
 
 
 SIGNAL CCR     : INTEGER := ARR/4; 
 SIGNAL ARR_old : INTEGER := 0;  

  
 SIGNAL First_time : STD_LOGIC := '0';
  
 
 BEGIN 
 

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

  
CMP: PROCESS(Clock_PFM) 


BEGIN

 
	
  IF (RISING_EDGE(Clock_PFM)) THEN


	IF (First_time = '0') THEN
	
		CCR <= ARR/4;
		First_time <= '1';
		ARR_old <= ARR;
		
		ELSE 
				
		CCR<= ARR_old/4;
		
	END IF;

	
	   COUNT_t <= COUNT_t+1;
	
	IF (2*COUNT_t < ARR_old) then -- ARR/2 
	
	   counter_val <= counter_val + 1;
	
	END IF;
	
	IF (2*COUNT_t > ARR_old) then -- ARR/2 
	
		counter_val <= counter_val-1;
	
	END IF;
	
	IF (COUNT_t = ARR_old) THEN 
	
		counter_val <= 0;
		COUNT_t <= 0;

		ARR_old <= ARR;
	
	END IF;
	
		
	IF (counter_val < CCR OR counter_val = 0 ) then 
	
		PFM_out <= '0';
	
	ELSE
	
		PFM_out <= '1';	

	
	END IF;
	
 END IF;

END PROCESS;


END PFM_GEN;