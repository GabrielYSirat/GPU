/*
 * microimagesRSV.cu
 *
 *  Created on: May 3, 2017
 *      Author: gabriel
 */

#include "NewLoop.h"
void readstoremicroimages(void) {
	char * memblock;
	long size;
	XMLDocument doc;
	float Maxmicroimages = 0.0f, Summicroimages = 0.0f;

	string MIraw = resourcesdirectory + "MI_created_11_11.raw";
	const char * MIRawfile   = "results/MIRawfile.pgm";

	printf("MICROIMAGES \u2464 ******************Read raw microimages **************\n");

	// buffer allocation, buffer in double for original data, buffer in float for working (to go to FP16) character for display
	cudaMallocManaged(&double_microimages, TA.Nb_LaserPositions * Npixel * Npixel * sizeof(double));
	cudaMallocManaged(&original_microimages, TA.Nb_LaserPositions * Npixel * Npixel * sizeof(float));
	cudaMallocManaged(&zoomed_microimages, TA.Nb_LaserPositions * PixZoomSquare * sizeof(float));
	cudaMallocManaged(&MIintile, tile.NbTile * tile.maxLaserintile * PixZoomSquare * sizeof(float));
	unsigned char *i_MIraw = (unsigned char*) calloc( TA.Nb_LaserPositions * Npixel * Npixel, sizeof(char));

	//read distrib bin file
	std::ifstream MIrawfile(MIraw.c_str(), ios::in | ios::binary | ios::ate);
	size = (MIrawfile.tellg()); 	// the data is stored in doubles of 8 bytes in the file
	size -= byte_skipped;  				// removes the 4 first bytes, Why??
	std::cout << "MICROIMAGES \u2464 function read: size microimages = " << size << endl;
	memblock = new char[size];
	MIrawfile.seekg(byte_skipped, ios::beg); // 4 first bytes are offset
	MIrawfile.read(memblock, size);
	MIrawfile.close();

	double_microimages = (double*) memblock; //reinterpret the chars stored in the file as double

	for (int i = 0; i < TA.Nb_LaserPositions * Npixel * Npixel; i++) {
		*(original_microimages + i) = *(double_microimages + i);			// change to float
		Summicroimages += original_microimages[i];
		Maxmicroimages = max(Maxmicroimages, *(original_microimages + i));
	}
	printf("MICROIMAGES \u2464 function read: Path to distrib original %s .....\n", MIRawfile);
	printf("MICROIMAGES \u2464 original on host: Average  %f max microimages %f \n", Summicroimages / (TA.Nb_LaserPositions * Npixel * Npixel),
			Maxmicroimages);


	// write microimages copy to disk
	/////////////////////////////////
	for (int i = 0; i < TA.Nb_LaserPositions * Npixel * Npixel; i++)
		i_MIraw[i] = 255.0 * original_microimages[i] / Maxmicroimages;			// image value
	printf("MICROIMAGES \u2464 host: Path to microimages original %s .....\n", MIRawfile);

	sdkSavePGM(MIRawfile, i_MIraw, TA.Nb_LaserPositions * Npixel,Npixel);

	free(i_MIraw);

}

bool validatemicroimages_control(void) {
	bool testmicroimages;
	double Sum3microimages = 0, max3microimages = 0;
	double Sum4microimages = 0, max4microimages = 0;
	const char * MIValfile   = "results/MIVALfile.pgm";
	const char * MIzoomfile   = "results/MIZOOMfile.pgm";

	// write microimages in memory and validate
	cudaMallocManaged(&valmicroimages, (TA.Nb_LaserPositions * Npixel * Npixel) * sizeof(float));
	unsigned char *i_MIVal = (unsigned char*) calloc( TA.Nb_LaserPositions * Npixel * Npixel, sizeof(char));
	unsigned char *i_MIzoom = (unsigned char*) calloc( TA.Nb_LaserPositions * PixZoom * PixZoom, sizeof(char));

	dim3 dimBlock(Npixel, Npixel, 1);
	dim3 dimGrid(pZOOM, pZOOM, 1);
	// Execute the microimages kernel
	validate_microimages<<<dimGrid, dimBlock, 0>>>( TA.Nb_LaserPositions);
	cudaDeviceSynchronize();
	for (int imicroimages = 0; imicroimages < (TA.Nb_LaserPositions * Npixel * Npixel); imicroimages++){
				Sum3microimages += *(valmicroimages + imicroimages);
				max3microimages = max(max3microimages, *(valmicroimages + imicroimages));
			}
	printf("MICROIMAGES \u2464 Copy from device: Average  %f max3microimages %f \n", Sum3microimages / (TA.Nb_LaserPositions * Npixel * Npixel),
			max3microimages);

	for (int imicroimages = 0; imicroimages < (TA.Nb_LaserPositions * PixZoom * PixZoom); imicroimages++){
				Sum4microimages += *(zoomed_microimages + imicroimages);
				max4microimages = max(max4microimages, *(zoomed_microimages + imicroimages));
			}
	printf("MICROIMAGES \u2464 Copy from device: zoomed image Average  %f max3microimages %f \n", Sum4microimages / (TA.Nb_LaserPositions * PixZoom * PixZoom),
			max4microimages);

	// write microimages image validation to disk
	/////////////////////////////////

	printf("MICROIMAGES \u2464 Comparing files ... ");
	testmicroimages = compareData(valmicroimages, original_microimages,
			TA.Nb_Cols_microimages * TA.Nb_Rows_microimages * Ndistrib,
			MAX_EPSILON_ERROR, 0.15f);

	for (int jmicroimages = 0; jmicroimages < (TA.Nb_LaserPositions * Npixel * Npixel); jmicroimages++) {
		Sumdel[4] += fabsf(*(valmicroimages + jmicroimages) - *(original_microimages + jmicroimages));
	}
	printf("Sumdel[4] %f  ", Sumdel[4]);
	cout << "testmicroimages = " << testmicroimages << "\n";

	// write microimages copy to disk
	/////////////////////////////////
	for (int i = 0; i < TA.Nb_LaserPositions * Npixel * Npixel; i++)
		i_MIVal[i] = 255.0 * valmicroimages[i] / max3microimages;			// image value
	printf("MICROIMAGES \u2464 host: Path to microimages copy %s .....\n", MIValfile);

	sdkSavePGM(MIValfile, i_MIVal,  TA.Nb_LaserPositions * Npixel,Npixel);

	free(i_MIVal);
	// write zoomed microimages  to disk
	/////////////////////////////////
	for (int i = 0; i < TA.Nb_LaserPositions * PixZoomSquare; i++)
		i_MIzoom[i] = 255.0 * zoomed_microimages[i] / max3microimages;			// correct sum image value
	printf("MICROIMAGES \u2464 host: Path to microimages zoomed %s .....\n", MIValfile);

	sdkSavePGM(MIzoomfile, i_MIzoom, TA.Nb_LaserPositions * PixZoom,PixZoom);
	free(i_MIzoom);


	cudaFree(valmicroimages);

	return (testmicroimages);
}

