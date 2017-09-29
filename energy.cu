/*
 * energy.cu
 *
 *  Created on: Sep 19, 2017
 *      Author: gabriel
 */

#include "NewLoop.h"
	__managed__ double Energy = 0.0f, absdiff = 0.0f;
float EnergyCal(void) {
	int it;
	for (int iimage =0; iimage < onhost.Nb_LaserPositions; iimage++)
		for (int ipix = 0; ipix < NThreads; ipix++) {
			it = ipix + iimage * NThreads;
			Energy += new_simus[it] - Data[it]*log(new_simus[it]+onhost.Bconstant);
			absdiff += abs(new_simus[it] - Data[it]);
			Rfactor[it] = 1 - Data[it] / (new_simus[it] + onhost.Bconstant);
		}
	printf("Energy %8.6f absdiff %8.6f\n\n", Energy, absdiff);
	return (Energy);
}

