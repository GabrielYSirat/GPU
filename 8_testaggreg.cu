#ifdef TESTAGG
	DD.step++;
	if (!iprint && !aggregx && !aggregy) printf("\n\u2463****************************DEVICE:  AGGREGATES & TILES****************\n");
	if (!iprint && VERBOSELOOP) printf("\u2463 AGGREGATE x %d y %d *****\n", aggregx, aggregy);
	if (!iprint && VERBOSELOOP) printf("\u2463 TILES tilex %d, tiley %d tile %d MemoryOffsetscratch %d\n",
			tilex, tiley, tileXY, MemoryOffsetscratch);
#endif

