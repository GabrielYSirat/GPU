#ifdef TESTDISTRIBDEVICE
	DD.step++;
	for (int idistrub = ithreads; idistrub < ADistrib; idistrub += THREADSVAL)
			*(test2_distrib + idistrub + itb * ADistrib) = *(shared_distrib + idistrub);
	for (int ipsf = 0; ipsf < PSFZOOMSQUARE; ipsf ++)
			*(test2_psf + ipsf) = *(original_PSF + ipsf);
	__syncthreads();
//    timer = clock64();
	if (!iprint)
		printf( "DEVICE: \u23f1**DEVICE:  step %d   TIMING (msec) ** processing  %f this step  %g  total %g \n",
			DD.step, (float) (timer - time_start) / DD.clockRate,
			(float) (  time_start - time_init) / DD.clockRate,
			(float) (timer - time_init) / DD.clockRate);
	if (!iprint) printf("\u2461 **********************************DEVICE:  DISTRIBUTIONS  ********************\n\n");
	__syncthreads();
#endif
