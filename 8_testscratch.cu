#ifdef TESTSCRATCH
DD.step++;
if(!ithreads)
for (int jscratch = 0; jscratch < ASCRATCH; jscratch ++) {
	val2_scratchpad[jscratch + MemoryOffsetscratch + distrib_number * ASCRATCH * DD.NbTileXY] = Scratchpad[jscratch]; // scratchpad image validation
	Sumscratch += val2_scratchpad[jscratch + MemoryOffsetscratch + distrib_number * ASCRATCH * DD.NbTileXY];
	maxscratch = max(Scratchpad[jscratch], maxscratch);
	if(*(Scratchpad + jscratch) != 0.0f && !ithreads) printf("DEVICE: \u2464 SCRATCHPAD ithreads %d itb %d position in scratchpad %d value %f Sum %f max %f\n",
			ithreads, itc, jscratch, *(Scratchpad + jscratch), Sumscratch, maxscratch);
}
if(((aggregx+1) == DD.NbAggregx) && ((aggregy+1) == DD.NbAggregy)) {
	if (!iprint) printf("DEVICE: \u2464 SUM SCRATCHPAD: Sum of scratchpad %5.1f Max of Scratchpad %5.1f \n", Sumscratch, maxscratch);
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