/*
 * 7_displayresults.cu
 *
 *  Created on: December 16, 2017
 *      Author: gabriel
 */

#include"0_Mainparameters.h"

float displaySimus(float * simusvalues, string filebase) {
	int sizesimus = tile.maxLaserintile * tile.NbTileXYD * NThreads;
	int sizesimus2D = tile.maxLaserintile * tile.NbTileXYD * PixZoomSquare;
	float MaxSimus2D = 0.0f, MinSimus2D = 1.E6, SumSimus2D = 0.0;
	int Nancounter = 0;
	string file;
	int n_colintern = PixZoom * tile.NbTileXYD;
	int n_rowintern = PixZoom * tile.maxLaserintile;

	unsigned char *i_simus = (unsigned char *) calloc(sizesimus2D, sizeof(unsigned char)); // on host

	for (int i = 0; i < sizesimus; i++) MaxSimus2D = max(MaxSimus2D, *(simusvalues + i)); // all distributions!!
	for (int i = 0; i < sizesimus; i++) SumSimus2D += *(simusvalues + i); // all distributions!!
	for (int i = 0; i < sizesimus; i++) MinSimus2D = min(MinSimus2D, *(simusvalues + i));
	for (int i = 0; i < sizesimus; i++) if(std::isnan(*(simusvalues + i))) {
		printf(" i %d value %f \n", i, *(simusvalues + i));
		Nancounter++;
	}
	float ratio = 255. / (MaxSimus2D - MinSimus2D);


	verbosefile << "HOST: \u24EF parameters: row simus " << n_rowintern << " col simus " << n_colintern << endl;
	cout << " Nan counter " << Nancounter << endl;
	verbosefile << " Maximum Simulations " << MaxSimus2D << " Minimum simulations " << MinSimus2D << " Sum " << SumSimus2D
			<<  " ratio " << ratio << " size " << sizesimus << endl;


		file = filebase + ".pgm"; verbosefile << "file " << file << endl;

		int ipix = 0;
		for (int isimus = 0; isimus < sizesimus; isimus++) {
			int imicro = isimus / NThreads; // number of microimage
			int ipixel = isimus % NThreads; // pixel number in microimage including void pixels
			if (ipixel < PixZoomSquare)
			{
				int ix = (ipixel % PixZoom) + PixZoom * (imicro % tile.maxLaserintile);
				int iy = (ipixel / PixZoom) + PixZoom * (imicro/tile.maxLaserintile );
				i_simus[ix + iy * PixZoom*tile.NbTileXYD] = ratio * (simusvalues[isimus] - MinSimus2D);
			}
		}
		sdkSavePGM(file.c_str(), i_simus, n_colintern, n_rowintern);


	return (TRUE);
}
