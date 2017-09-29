#ifdef STARTDEVICE
DD.step++;
	if (!itb) timer = clock64();
		if (!iprint)  	// the condition is required to have it printed once
			printf( "DEVICE: \u23f1**DEVICE:  step %d   TIMING ** processing  %g from start  %g  total %g \n\n",
					DD.step, (float) (timer - time_start) / CLOCKS_PER_SEC,
					(float) (  time_start - time_init) / CLOCKS_PER_SEC,
					(float) (timer - time_init) / CLOCKS_PER_SEC);
		__syncthreads();
			if (!itb) time_start = clock64();
		
#endif
