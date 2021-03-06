/*
 * microimagesRSV.cu
 *
 *  Created on: May 3, 2017
 *      Author: gabriel
 */

#include "0_Mainparameters.h"

double * double_microimages;
std::string endMI = ".bin";
float Maxmicroimages = 0.0f, Summicroimages = 0.0f, Minmicroimages = 1.e20;

void readstoremicroimages(void) {
	char * memblock;
	long size;
	const char * MIRawfile = "results/C_microimages.pgm";

	// buffer allocation, buffer in double for original data, buffer in float for working (to go to FP16) character for display
	double_microimages = (double *) calloc(TA.Nb_LaserPositions * PixSquare, sizeof(double));
	cudaMallocManaged(&original_microimages, TA.Nb_LaserPositions * PixSquare * sizeof(float));
	cudaMallocManaged(&zoomed_microimages, TA.Nb_LaserPositions * PixZoomSquare * sizeof(float));
	unsigned char *i_MIraw = (unsigned char*) calloc(Ndistrib*PixSquare * tile.maxlaserperdistribution, sizeof(char));

	verbosefile << "MICROIMAGES \u2464 Total number of images for all distributions " <<  TA.Nb_LaserPositions << " from laser XML file "<< endl;
	int numberofpixels = 0;
	for (int idistrib = 0; idistrib < Ndistrib; idistrib++) {
		std::string MIraw = resourcesdirectory + MIFILE + std::to_string(idistrib + 1) + endMI;
		verbosefile << "MICROIMAGES \u2464 function read: distribution n°" << idistrib << " Path to distrib original .....\n" << MIraw.c_str() << endl;

		std::ifstream MIrawfile(MIraw.c_str(), ios::in | ios::binary | ios::ate); 		//read distrib bin file
		size = (MIrawfile.tellg()) ; 	// the data is stored in doubles of 8 bytes in the file
		size -= byte_skipped;
		memblock = new char[size];
		MIrawfile.seekg(byte_skipped, ios::beg); // byte_skipped first bytes are offset
		MIrawfile.read(memblock, size);
		MIrawfile.close();
		verbosefile << "MICROIMAGES \u2464 function read: distrib n°" << idistrib << " number laser positions "
				<< tile.Nblaserperdistribution[idistrib] << " size microimages = " << size <<
				" to be " << PixSquare * tile.Nblaserperdistribution[idistrib]*sizeof(double) << endl;
		verbosefile << "MICROIMAGES \u2464 number of images " << tile.Nblaserperdistribution[idistrib] <<
				" Number of pixels " << tile.Nblaserperdistribution[idistrib] * PixSquare << endl;

		double_microimages = (double*) memblock; //reinterpret the chars stored in the file as double
		for (int i = 0; i < tile.Nblaserperdistribution[idistrib] * PixSquare; i++) {
			*(original_microimages + i + numberofpixels) = *(double_microimages + i);			// change to float
			Summicroimages += original_microimages[i + numberofpixels];
			Maxmicroimages = max(Maxmicroimages, *(original_microimages + i + numberofpixels));
			Minmicroimages = min(Minmicroimages, *(original_microimages + i + numberofpixels));
		}
		numberofpixels += tile.Nblaserperdistribution[idistrib] * PixSquare;
		verbosefile << "MICROIMAGES \u2464 original on host: Average " << Summicroimages / numberofpixels
				<< " microimages: max " <<  Maxmicroimages << " min " << Minmicroimages << endl;
	}

	for (int idistrib = 0; idistrib < Ndistrib; idistrib++)
		for (int ilaser = 0; ilaser < tile.Nblaserperdistribution[idistrib]; ilaser++)
			for (int xpix = 0; xpix < Npixel; xpix++)
				for (int ypix = 0; ypix < Npixel; ypix++) {
					int itemp = xpix + idistrib* Npixel + Npixel *Ndistrib * ypix + Ndistrib * PixSquare * ilaser;
					int itemp2 = xpix + Npixel*ypix + PixSquare * (idistrib * tile.Nblaserperdistribution[idistrib] + ilaser);
					i_MIraw[itemp] = 255.0 * (original_microimages[itemp2] - Minmicroimages)
							/ (Maxmicroimages - Minmicroimages);
				}
	verbosefile << "MICROIMAGES \u2464 host: Path to microimages original " << MIRawfile << " .....\n";

	sdkSavePGM(MIRawfile, i_MIraw,  Npixel * Ndistrib, tile.maxlaserperdistribution * Npixel);

	free(i_MIraw);

}

bool validatemicroimages_control(void) {
	bool testmicroimages;
	double Sum3microimages = 0, max3microimages = 0;
	double Sum4microimages = 0, max4microimages = 0;
	const char * MIValfile = "results/C_microimagesdevice.pgm";
	const char * MIzoomfile = "results/C_microimagesdevicezoom.pgm";

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
	verbosefile << "MICROIMAGES \u2464 Copy from device: Average " << Sum3microimages / (TA.Nb_LaserPositions * PixSquare);
	verbosefile << "max3microimages " << max3microimages << endl;

	for (int imicroimages = 0; imicroimages < (TA.Nb_LaserPositions * PixZoom * PixZoom); imicroimages++) {
		Sum4microimages += *(zoomed_microimages + imicroimages);
		max4microimages = max(max4microimages, *(zoomed_microimages + imicroimages));
	}
	verbosefile << "MICROIMAGES \u2464 Copy from device: zoomed image Average " << Sum4microimages / (TA.Nb_LaserPositions * PixZoom * PixZoom);
	verbosefile << "max3microimages " << max4microimages << endl;

	// write microimages image validation to disk
	/////////////////////////////////

	verbosefile << "MICROIMAGES \u2464 Comparing files ... ";
	testmicroimages = compareData(valmicroimages, original_microimages,
			TA.Nb_Cols_microimages * TA.Nb_Rows_microimages * Ndistrib,
			MAX_EPSILON_ERROR, 0.15f);

	for (int jmicroimages = 0; jmicroimages < (TA.Nb_LaserPositions * PixSquare); jmicroimages++) {
		Sumdel[4] += fabsf(*(valmicroimages + jmicroimages) - *(original_microimages + jmicroimages));
	}
	verbosefile << "Sumdel[4] " << Sumdel[4];
	verbosefile << "testmicroimages = " << testmicroimages << "\n";

	// write microimages copy to disk
	/////////////////////////////////
	for (int idistrib = 0; idistrib < Ndistrib; idistrib++)
		for (int ilaser = 0; ilaser < tile.Nblaserperdistribution[idistrib]; ilaser++)
			for (int xpix = 0; xpix < Npixel; xpix++)
				for (int ypix = 0; ypix < Npixel; ypix++) {
					int itemp = xpix + idistrib* Npixel + Npixel *Ndistrib * ypix + Ndistrib * PixSquare * ilaser;
					int itemp2 = xpix + Npixel*ypix + PixSquare * (idistrib * tile.Nblaserperdistribution[idistrib] + ilaser);
					i_MIVal[itemp] = 255.0 * (valmicroimages[itemp2] - Minmicroimages)
							/ (Maxmicroimages - Minmicroimages);
				}

	for (int idistrib = 0; idistrib < Ndistrib; idistrib++)
		for (int ilaser = 0; ilaser < tile.Nblaserperdistribution[idistrib]; ilaser++)
			for (int xpix = 0; xpix < PixZoom; xpix++)
				for (int ypix = 0; ypix < PixZoom; ypix++) {
					int itemp = xpix + idistrib* PixZoom + PixZoom *Ndistrib * ypix + Ndistrib * PixZoomSquare * ilaser;
					int itemp2 = xpix + PixZoom*ypix + PixZoomSquare * (idistrib * tile.Nblaserperdistribution[idistrib] + ilaser);
					i_MIzoom[itemp] = 255.0 * (zoomed_microimages[itemp2] - Minmicroimages)
							/ (Maxmicroimages - Minmicroimages);
				}


	verbosefile << "MICROIMAGES \u2464 host: Path to microimages copy " << MIValfile << " .....\n";

	sdkSavePGM(MIValfile, i_MIVal,  Npixel * Ndistrib, tile.maxlaserperdistribution * Npixel);
	sdkSavePGM(MIzoomfile, i_MIzoom, PixZoom * Ndistrib, tile.maxlaserperdistribution * PixZoom);

	free(i_MIVal);	free(i_MIzoom);
	cudaFree(valmicroimages);
	return (testmicroimages);
}

