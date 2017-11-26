#ifdef TESTAGG
	DD.step++;
	if(!itc && VERBOSELOOP) printf(" \u2463******DEVICE:  AGGREGATES x %d y %d *****\n", aggregx, aggregy);
	if (!iprint) printf("end \u2463***********************DEVICE:  AGGREGATES & TILES*****************\n");
	if (!iprint) printf("DEVICE:\u2463 AGGREGATES \nDEVICE:\u2463 TILES tilex %d, tiley %d tile %d MemoryOffsetscratch %d\n",
			tilex, tiley, tileXY, MemoryOffsetscratch);
	if (!iprint) printf("end \u2463***********************DEVICE:  AGGREGATES & TILES*****************\n");

#endif

#ifdef TESTSCRATCH
	if(!ithreads)
		for (int jscratch = 0; jscratch < ASCRATCH; jscratch ++){
		Sumscratch += *(Scratchpad + jscratch);
		maxscratch = max(Scratchpad[jscratch], maxscratch);
		val2_scratchpad[jscratch + MemoryOffsetscratch] = Scratchpad[jscratch];  // scratchpad image validation
		if(*(Scratchpad + jscratch) != 0.0f && !ithreads) printf("ithreads %d itb %d position in scratchpad %d value %f Sum %f max %f\n",
				ithreads, itc, jscratch, *(Scratchpad + jscratch), Sumscratch, maxscratch);
	}

	if (!iprint) printf("DEVICE: \u2464 SUM SCRATCHPAD: Sum of scratchpad %5.1f Max of Scratchpad %5.1f \n", Sumscratch, maxscratch);
	if (!iprint)
		printf( "DEVICE: \u23f1**DEVICE:  step %d   TIMING (msec) ** processing  %f from start  %g  total %g \n",
			DD.step, (float) (timer - time_start) / DD.clockRate,
			(float) (  time_start - time_init) / DD.clockRate,
			(float) (timer - time_init) / DD.clockRate);
	if (!iprint) printf("end \u2464*******************************DEVICE:  SCRATCHPAD ********************\n\n");
			__syncthreads();

#endif
