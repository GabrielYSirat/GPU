/*
 * readStorevalidatedistrib_control.cu
 *
 *  Created on: Apr 23, 2017
 *      Author: gabriel
 */
#include "NewLoop.h"
int byte_skipped = 16;
float Maxdistrib = 0.0f, Sumdistrib = 0.0f;
std::string DISDATA = "/lambda_488/Calib/distribution";
const char * distribImagefile = "results/distribImagefile.pgm";


void readstoredistrib(void) {
	char * memblock;
	int size;

	unsigned char *ii_distrib = (unsigned char *) calloc( YDistrib_extended * XDistrib * Ndistrib, sizeof(unsigned char)); // on host
	cudaMallocManaged(&original_distrib, ADistrib * Ndistrib * sizeof(double));
	cudaMallocManaged(&double_distrib, YDistrib_extended * XDistrib * Ndistrib * sizeof(float));
	cudaMallocManaged(&test_distrib, XDistrib * YDistrib * Ndistrib * sizeof(double));

	for(int idistrib = 0; idistrib < Ndistrib; idistrib++)
	{
	std::string beadraw = resourcesdirectory + DISDATA + std::to_string(idistrib+1) + ".bin";
	printf("DISTRIBUTIONS \u2461: data file %s\n",beadraw.c_str());

	//read distrib bin file
	std::ifstream distribile(beadraw.c_str(), ios::in | ios::binary | ios::ate);
	size = (distribile.tellg()); // the data is stored in doubles of 8 bytes in the file
	size -= byte_skipped;  				// removes the 4 first bytes, Why??
	cout << "DISTRIBUTIONS \u2461 function read: distribution # " << idistrib << " size distrib = "<< size << endl;
	memblock = new char[size];
	distribile.seekg(byte_skipped, ios::beg); // 4 first bytes are offset
	distribile.read(memblock, size);
	distribile.close();

	double_distrib = (double*) memblock; //reinterpret the chars stored in the file as double

	for (int i = 0; i < ADistrib; i++) {
		*(original_distrib + i + idistrib*XDistrib*YDistrib_extended) = *(double_distrib + i);	// change to float
		Sumdistrib += double_distrib[i];
		Maxdistrib = max(Maxdistrib, *(double_distrib + i));
	}
	printf("DISTRIBUTIONS \u2461: idistrib %d Original max %g Sum %g\n", idistrib, Maxdistrib, Sumdistrib);
	}
	// write distrib image to disk
	/////////////////////////////////
	for (int i = 0; i < YDistrib_extended * XDistrib * Ndistrib; i++)
		ii_distrib[i] = 255.0 * original_distrib[i] / Maxdistrib;// image value
	printf(
			"DISTRIBUTIONS \u2461 function read: Path to distrib original %s .....\n",
			distribImagefile);

	sdkSavePGM(distribImagefile, ii_distrib, XDistrib, YDistrib_extended * Ndistrib);

	free(ii_distrib);

}

bool Distribvalidate_host(void) {
	bool testdistrib;
	double Sum3distrib = 0, max3distrib = 0;

	unsigned char *ii_distrib = (unsigned char *) calloc( YDistrib_extended * XDistrib * Ndistrib, sizeof(unsigned char)); // on host
	// write distrib in memory and validate
	cudaMallocManaged(&val_distrib, YDistrib_extended * XDistrib * Ndistrib * sizeof(float));
	const char * distribValImagefile = "results/distribValImagefile.pgm";

	dim3 dimBlock(1, 1, 1);
	dim3 dimGrid(1, 1, 1);
	// Execute the distrib kernel
	validate_distrib<<<dimGrid, dimBlock, 0>>>(YDistrib_extended, XDistrib, Ndistrib);
	cudaDeviceSynchronize();

	for (int arg = 0; arg < ADistrib * Ndistrib; arg++)	Sum3distrib += *(val_distrib + arg);
	for (int arg = 0; arg < ADistrib * Ndistrib; arg++) max3distrib = max(max3distrib, *(val_distrib + arg));

	printf("DISTRIBUTIONS \u2461: validation max %g Sum %g\n", max3distrib, Sum3distrib);

	for (int i = 0; i < YDistrib_extended * XDistrib * Ndistrib; i++)
		ii_distrib[i] = (255.0 * val_distrib[i]) / max3distrib;// Validation image value

	printf(" DISTRIBUTIONS \u2461 Path to distrib validation %s .....\n", distribValImagefile);

	sdkSavePGM(distribValImagefile, ii_distrib, XDistrib, YDistrib_extended * Ndistrib);

	printf(" DISTRIBUTIONS \u2461 Comparing files ... ");
	testdistrib = compareData(val_distrib, original_distrib,
			XDistrib * YDistrib_extended * Ndistrib,
			MAX_EPSILON_ERROR, 0.15f);

	for (int jdistrib = 0; jdistrib < YDistrib_extended * XDistrib * Ndistrib;
			jdistrib++) {
		Sumdel[1] += fabsf(
				*(val_distrib + jdistrib) - *(original_distrib + jdistrib));
	}
	printf("Sumdel[1] %f  ", Sumdel[1]);
	cout << "testdistrib = " << testdistrib << "\n";
	cudaFree(val_distrib);
	return (testdistrib);
}

