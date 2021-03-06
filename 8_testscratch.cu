#ifdef TESTSCRATCH
DD.step++;
float Sumscratchval=0.0f, Maxscratchval=0.0f;

	for (int jscratch = 0; jscratch < ASCRATCH; jscratch ++) {
		val2_scratchpad[jscratch + scrglobal - scratchpad_matrix] = Scratchpad[jscratch]; // scratchpad image validation
		int delta = jscratch + scrglobal - scratchpad_matrix - lostpixels;
//		int x = delta%XSCRATCH; int y = delta/YSCRATCH;
		Sumscratchval += val2_scratchpad[jscratch + scrglobal - scratchpad_matrix];
		Maxscratchval = max(Scratchpad[jscratch], Maxscratchval);
		if(*(Scratchpad + jscratch) != 0.0f && !ithreads)
			printf("DEVICE: \u2463 SCRATCHPAD distrib_number %d itb %d delta %d position (x*y) (%d*%d) position in scratchpad %d value %f Sum %f max %f\n",
					distrib_number, itb, delta, (delta-DD.lostpixelsdevice)%(XSCRATCH*tilexdevice), (delta - DD.lostpixelsdevice)/(XSCRATCH*tilexdevice), jscratch, *(Scratchpad + jscratch), Sumscratchval, Maxscratchval);
	}
	__syncthreads();

	if (!iprint) printf("end \u2463**********DEVICE:  SCRATCHPAD *aggregate  (%d*%d) *****************\n\n", aggregx, aggregy);
__syncthreads();

if(((aggregx+1) == DD.NbAggregx) && ((aggregy+1) == DD.NbAggregy)) {
	if (!iprint) printf("DEVICE: \u2464 SUM SCRATCHPAD: Sum of scratchpad %5.1f Max of Scratchpad %5.1f \n", Sumscratchval, Maxscratchval);
	if (!iprint) timer = clock64();

	if (!iprint)
	printf( "DEVICE: \u23f1**DEVICE:  step %d   TIMING (msec) ** processing  %f this step  %g  total %g \n",
			DD.step, (float) (timer - time_start) / DD.clockRate,
			(float) ( time_start - time_init) / DD.clockRate,
			(float) (timer - time_init) / DD.clockRate);
	if (!iprint) printf("end \u2464****************DEVICE:  SCRATCHPAD & AGGREGATES & TILES ********************\n\n");
}
__syncthreads();

#endif
