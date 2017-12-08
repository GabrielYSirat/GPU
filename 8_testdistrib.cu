#ifdef TESTDISTRIBDEVICE
float Maxdistrib2 = 0.0f;
	DD.step++;
	for (int idistrub = ithreads; idistrub < ADistrib; idistrub += THREADSVAL)
			*(test2_distrib + idistrub + itb * ADistrib) = *(shared_distrib + idistrub);
	for (int ipsf = 0; ipsf < PSFZOOMSQUARE; ipsf ++)
			*(test2_psf + ipsf) = *(original_PSF + ipsf);
	for (int idistrub = 0; idistrub < ADistrib; idistrub ++){
		Maxdistrib2 = max(Maxdistrib2, *(test2_distrib + idistrub + itb * ADistrib));
	}

		__syncthreads();
//    timer = clock64();
		if (!iprint)
			printf("DEVICE: \u23f1**DEVICE: MaxDistribution2 %f       \n", Maxdistrib2);
	if (!iprint)
		printf( "DEVICE: \u23f1**DEVICE:  step %d   TIMING (msec) ** processing  %f this step  %g  total %g \n",
			DD.step, (float) (timer - time_start) / DD.clockRate,
			(float) (  time_start - time_init) / DD.clockRate,
			(float) (timer - time_init) / DD.clockRate);
	if (!iprint) printf("\u2461 **********************************DEVICE:  DISTRIBUTIONS  ********************\n\n");
	__syncthreads();
#endif
