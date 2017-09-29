/*#ifdef TESTDISTRIB

if (!iprint && !apix)
		printf("\u2466****************************DEVICE:  DISTRIBPOS****************\n\n");
		if (!iprint || (!(ithreads%65)))
			printf("\u2466 apix %d ithreads %d ipixel %d, jpixel %d, values of distribpos: %d value of distribution in shared memory %g\n",
			apix, ithreads, ipixel[apix], jpixel[apix], distribpos[apix], *(shared_distrib + distribpos[apix]));

		double SumDistrib_shared = 0.0f,  MaxShared = 0.0f;
		for (int ilarge = 0; ilarge < ADistrib; ilarge ++){
		if(MaxShared < *(shared_distrib + ilarge)) MaxShared = *(shared_distrib + ilarge);
		SumDistrib_shared += *(shared_distrib + ilarge);
		}
		if (!iprint)
		printf("\u2462 DEVICE: distrib SumShared %6.3f MaxShared %6.3f \n", SumDistrib_shared, MaxShared);
if (!iprint && (apix == (THreadsRatio-1)))
		printf("\u2466****************************DEVICE:  DISTRIBPOS****************\n\n");
__syncthreads();



#endif*/
