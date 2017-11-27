#ifdef DISTRIBPOS
	DD.step++;

	if(!iprint && ((aggregx+1) == DD.NbAggregx) && ((aggregy+1) == DD.NbAggregy)) {
		for (int apix = 0; apix < THreadsRatio; apix++)
		printf("DEVICE: \u23f2 APIX DISTRIB: apix %d distribpos[apix] %d \n", apix, distribpos[apix]);
// validé

	if (!iprint) timer = clock64();
	if (!iprint)
		printf( "DEVICE: \u23f1**DEVICE:  step %d   TIMING (msec) ** processing  %f this step  %g  total %g \n",
			DD.step, (float) (timer - time_start) / DD.clockRate,
			(float) (  time_start - time_init) / DD.clockRate,
			(float) (timer - time_init) / DD.clockRate);
	}
	__syncthreads();
#endif
