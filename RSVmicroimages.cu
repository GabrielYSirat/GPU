/*
 * microimagesRSV.cu
 *
 *  Created on: May 3, 2017
 *      Author: gabriel
 */

#include "NewLoop.h"

double * double_microimages;
std::string endMI = ".bin";
float Maxmicroimages = 0.0f, Summicroimages = 0.0f, Minmicroimages = 1.e20;

void readstoremicroimages(void) {
	char * memblock;
	long size;
	const char * MIRawfile = "results/MIRawfile.pgm";

	// buffer allocation, buffer in double for original data, buffer in float for working (to go to FP16) character for display
	double_microimages = (double *) calloc(TA.Nb_LaserPositions * PixSquare, sizeof(double));
	cudaMallocManaged(&original_microimages, TA.Nb_LaserPositions * PixSquare * sizeof(float));
	cudaMallocManaged(&zoomed_microimages, TA.Nb_LaserPositions * PixZoomSquare * sizeof(float));
	cudaMallocManaged(&MIintile, tile.NbTile * tile.maxLaserintile * PixZoomSquare * sizeof(float));
	unsigned char *i_MIraw = (unsigned char*) calloc(Ndistrib*PixSquare * tile.maxlaserperdistribution, sizeof(char));

	printf("MICROIMAGES \u2464 Total number of images for all distributions %d\n", TA.Nb_LaserPositions);
	int numberofpixels = 0;
	for (int idistrib = 0; idistrib < Ndistrib; idistrib++) {
		;
		std::string MIraw = resourcesdirectory + MIFILE + std::to_string(idistrib + 1) + endMI;
		printf("MICROIMAGES \u2464 function read: distribution n°%d Path to distrib original .....\n %s \n", idistrib,
				MIraw.c_str());

		//read distrib bin file
		std::ifstream MIrawfile(MIraw.c_str(), ios::in | ios::binary | ios::ate);
		size = (MIrawfile.tellg()); 	// the data is stored in doubles of 8 bytes in the file
		size -= byte_skipped;  				// removes the 4 first bytes, Why??
		std::cout << "MICROIMAGES \u2464 function read: distrib n°" << idistrib << " number laser positions "
				<< tile.Nblaserperdistribution[idistrib] << " size microimages = " << size << endl;
		memblock = new char[size];
		MIrawfile.seekg(byte_skipped, ios::beg); // byte_skipped first bytes are offset
		MIrawfile.read(memblock, size);
		MIrawfile.close();

		double_microimages = (double*) memblock; //reinterpret the chars stored in the file as double
		printf("number of images %d Number of pixels %d \n", tile.Nblaserperdistribution[idistrib],
				tile.Nblaserperdistribution[idistrib] * PixSquare);
		for (int i = 0; i < tile.Nblaserperdistribution[idistrib] * PixSquare; i++) {
			*(original_microimages + i + numberofpixels) = *(double_microimages + i);			// change to float
			Summicroimages += original_microimages[i];
			Maxmicroimages = max(Maxmicroimages, *(original_microimages + i));
			Minmicroimages = min(Minmicroimages, *(original_microimages + i));
		}
		numberofpixels += tile.Nblaserperdistribution[idistrib] * PixSquare;
		printf("MICROIMAGES \u2464 original on host: Average  %f max microimages %f \n",
				Summicroimages / numberofpixels, Maxmicroimages);

	}
	for (int idistrib = 0; idistrib < Ndistrib; idistrib++)
		for (int ilaser = 0; ilaser < tile.Nblaserperdistribution[idistrib]; ilaser++)
			for (int xpix = 0; xpix < Npixel; xpix++)
				for (int ypix = 0; ypix < Npixel; ypix++) {
					int itemp = xpix + Npixel * ypix + PixSquare * ilaser + idistrib*PixSquare * tile.maxlaserperdistribution;
					i_MIraw[itemp] = 255.0 * (original_microimages[itemp] - Minmicroimages)
							/ (Maxmicroimages - Minmicroimages);
				}
	printf("MICROIMAGES \u2464 host: Path to microimages original %s .....\n", MIRawfile);

	sdkSavePGM(MIRawfile, i_MIraw,  Npixel * Ndistrib, tile.maxlaserperdistribution * Npixel);

	free(i_MIraw);

}

bool validatemicroimages_control(void) {
	bool testmicroimages;
	double Sum3microimages = 0, max3microimages = 0;
	double Sum4microimages = 0, max4microimages = 0;
	const char * MIValfile = "results/MIVALfile.pgm";
	const char * MIzoomfile = "results/MIZOOMfile.pgm";

	// write microimages in memory and validate
	cudaMallocManaged(&valmicroimages, (TA.Nb_LaserPositions * PixSquare) * sizeof(float));
	unsigned char *i_MIVal = (unsigned char*) calloc(TA.Nb_LaserPositions * PixSquare, sizeof(char));
	unsigned char *i_MIzoom = (unsigned char*) calloc(TA.Nb_LaserPositions * PixZoom * PixZoom, sizeof(char));

	dim3 dimBlock(1, 1, 1);
	dim3 dimGrid(1, 1, 1);
	// Execute the microimages kernel
	validate_microimages<<<dimBlock, dimGrid,  0>>>(TA.Nb_LaserPositions);
	cudaDeviceSynchronize();
	for (int imicroimages = 0; imicroimages < (TA.Nb_LaserPositions * PixSquare); imicroimages++) {
		Sum3microimages += *(valmicroimages + imicroimages);
		max3microimages = max(max3microimages, *(valmicroimages + imicroimages));
	}
	printf("MICROIMAGES \u2464 Copy from device: Average  %f max3microimages %f \n",
			Sum3microimages / (TA.Nb_LaserPositions * PixSquare), max3microimages);

	for (int imicroimages = 0; imicroimages < (TA.Nb_LaserPositions * PixZoom * PixZoom); imicroimages++) {
		Sum4microimages += *(zoomed_microimages + imicroimages);
		max4microimages = max(max4microimages, *(zoomed_microimages + imicroimages));
	}
	printf("MICROIMAGES \u2464 Copy from device: zoomed image Average  %f max3microimages %f \n",
			Sum4microimages / (TA.Nb_LaserPositions * PixZoom * PixZoom), max4microimages);

	// write microimages image validation to disk
	/////////////////////////////////

	printf("MICROIMAGES \u2464 Comparing files ... ");
	testmicroimages = compareData(valmicroimages, original_microimages,
			TA.Nb_Cols_microimages * TA.Nb_Rows_microimages * Ndistrib,
			MAX_EPSILON_ERROR, 0.15f);

	for (int jmicroimages = 0; jmicroimages < (TA.Nb_LaserPositions * PixSquare); jmicroimages++) {
		Sumdel[4] += fabsf(*(valmicroimages + jmicroimages) - *(original_microimages + jmicroimages));
	}
	printf("Sumdel[4] %f  ", Sumdel[4]);
	cout << "testmicroimages = " << testmicroimages << "\n";

	// write microimages copy to disk
	/////////////////////////////////
	for (int idistrib = 0; idistrib < Ndistrib; idistrib++)
		for (int ilaser = 0; ilaser < tile.Nblaserperdistribution[idistrib]; ilaser++)
			for (int xpix = 0; xpix < Npixel; xpix++)
				for (int ypix = 0; ypix < Npixel; ypix++) {
					int itemp = xpix + Npixel * ypix + PixSquare * ilaser
							+ idistrib * PixSquare * tile.maxlaserperdistribution;
					i_MIVal[itemp] = 255.0 * (valmicroimages[itemp] - Minmicroimages)
							/ (Maxmicroimages - Minmicroimages);
					for (int xpixzoom = 0; xpixzoom < PixZoom; xpixzoom++)
						for (int ypixzoom = 0; ypixzoom < PixZoom; ypixzoom++) {
							int itemp = xpixzoom + PixZoom * ypixzoom + PixZoomSquare * ilaser
									+ idistrib * PixZoomSquare * tile.maxlaserperdistribution;
							i_MIzoom[itemp] = 255.0 * (zoomed_microimages[itemp] - Minmicroimages)
									/ (Maxmicroimages - Minmicroimages);
						}
				}
	printf("MICROIMAGES \u2464 host: Path to microimages copy %s .....\n", MIValfile);

	sdkSavePGM(MIValfile, i_MIVal,  Npixel * Ndistrib, tile.maxlaserperdistribution * Npixel);
	sdkSavePGM(MIzoomfile, i_MIzoom, PixZoom * Ndistrib, tile.maxlaserperdistribution * PixZoom);

	free(i_MIVal);	free(i_MIzoom);
	cudaFree(valmicroimages);
	return (testmicroimages);
}

