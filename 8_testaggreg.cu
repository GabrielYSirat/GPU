#ifdef TESTAGG
	DD.step++;
	if (!iprint && !aggregx && !aggregy) printf("\n\u2463****************************DEVICE:  AGGREGATES & TILES****************\n");
	if (!iprint && VERBOSELOOP) printf("\u2463 AGGREGATE x %d y %d ***************************************\n", aggregx, aggregy);
	if (!iprint && VERBOSELOOP) printf("\u2463 TILES tilexdevice %d, tileydevice %d tile %d MemoryOffset %d\n",
			tilexdevice, tileydevice, tileXY, MemoryOffset);
	if (!iprint && VERBOSELOOP) printf("\u2463 AGGREGATE x %d y %d ***************************************\n\n", aggregx, aggregy);
#endif

