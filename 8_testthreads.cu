#ifdef TESTTHREADS
	DD.step++;
	if (!iprint) printf("\n\u2461*******************************DEVICE:  THREADS *********************\n");
	__syncthreads();

		for (int apix = 0; apix < THreadsRatio; apix++)
				if (   (ithreads == 32))
						printf("DEVICE: \u2461 : apix %d ithreads %d\n", apix, ithreads);
	if (!iprint)
		printf( "DEVICE: \u23f1**DEVICE:  step %d   TIMING (msec) ** processing  %g this step  %g  total %g \n",
			DD.step, (float) (timer - time_start) / DD.clockRate,
			(float) (  time_start - time_init) / DD.clockRate,
			(float) (timer - time_init) / DD.clockRate);
	time_start = clock64();
	if (!iprint) printf("\u2461 **********************************DEVICE:  THREADS  ********************\n\n");
	__syncthreads();
#endif
