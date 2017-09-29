/*
 * initparameters.cu
 *
 *  Created on: May 7, 2017
 *      Author: gabriel
 */
/*
 * readLaserPositions.cu
 *
 *  Created on: April 18, 2017
 *      Author: gabriel
 */

#include "NewLoop.h"

__managed__ int XTile, YTile, ATile;
__managed__ int THreadsRatio, NThreads;
__managed__ int XDistrib, YDistrib, YDistrib_extended, lostlines, ADistrib;


cudaDeviceProp deviceProps;

bool initparameters( int argc, char **argv) {
	XMLDocument XMLdoc, ACQXML, doc;
	XMLElement *pRoot, *pParm;
	string sstr, filenamexml;
;
	bool dimfit = TRUE;

	// acquire information on the CUDA device: name and number of multiprocessors
	devID = gpuDeviceInit(devID);

	std::cout << "MAIN PROGRAM  \u24EA NewLoop starting...";
	if (devID < 0) {
		printf("exiting...\n");
		exit(EXIT_FAILURE);
	}
	checkCudaErrors(cudaGetDeviceProperties(&deviceProps, devID)); 	// get device name & properties
	TA.MP = deviceProps.multiProcessorCount;
	TA.sharedmemory = deviceProps.sharedMemPerBlock;
	clockRate = deviceProps.clockRate;
	printf(" INIT PROG \u24EA Number of Multiprocessors (MP) %d, clock rate (KHz) %d SharedMemory %6.3f in KBytes\n\n",
			TA.MP, clockRate, (float) TA.sharedmemory/1024.);

	/***************************** FILES MANAGEMENT ***********************************/
	resourcesdirectory = argv[1]; // Directory with all preprocessing files and data
	pPSF = retrieveargv(argv[2]);
	Npixel = retrieveargv(argv[3]);
	RDISTRIB = retrieveargv(argv[4]);
	pZOOM = retrieveargv(argv[5]);
	Ndistrib = retrieveargv(argv[6]);
	// to read the values in the program and to add tests

	std::cout << "MAIN PROGRAM  \u24EA ARG: EXE arguments number argc: " << argc << endl;
	std::cout << "MAIN PROGRAM  \u24EA Line of command parameters: " << "******************************************"
			<< endl;
	std::cout << "MAIN PROGRAM  \u24EA ARG: argv[1]: working directory: " << resourcesdirectory << endl;
	std::cout << "MAIN PROGRAM  \u24EA ARG: argv[2]: pPSF: " << pPSF << endl;
	std::cout << "MAIN PROGRAM  \u24EA ARG: argv[3]: Npixel: " << Npixel << endl;
	std::cout << "MAIN PROGRAM  \u24EA ARG: argv[4]: RDISTRIB: " << RDISTRIB << endl;
	std::cout << "MAIN PROGRAM  \u24EA ARG: argv[5]: pZOOM: " << pZOOM << endl;
	std::cout << "MAIN PROGRAM  \u24EA ARG: argv[6]: NDISTRIB: " << Ndistrib << endl;
	std::cout << "MAIN PROGRAM  \u24EA Line of command parameters: " << "******************************************"
			<< endl << endl;
	std::cout << "MAIN PROGRAM  \u24EA NewLoop starting...";

	/** initialize the general parameters and the offset & scale parameters
	 */
	TA.start();
	OFSCAL.start();

	filename = resourcesdirectory + "ACQ.xml";
	printf("filename %s \n", filename.c_str());
	printf(" INIT PROG \u24EA  scan points:  %s \n", filename.c_str());
	int LoadACQOK = XMLError(ACQXML.LoadFile(filename.c_str()));
	pRoot = ACQXML.FirstChildElement("BioAxialAcquisitionRequest");
	pParm = pRoot->FirstChildElement("LambdaParameters")->FirstChildElement("LambdaParameter")->FirstChildElement("dx");
	sstr = pParm->GetText();
	for (unsigned int i = 0; i < strlen(chars); ++i)
		sstr.erase(std::remove(sstr.begin(), sstr.end(), chars[i]), sstr.end());
	stringstream stream_x(sstr);
	stream_x.getline(buff, 10, ',');
	TA.dx = max(atoi(buff), TA.dx);
	if (verbose)
		cout << "verbose x: " << stream_x.str() << " y: ";

	pParm = pRoot->FirstChildElement("Camera_parameters")->FirstChildElement("PixelSize_nm");
	sstr = pParm->GetText();
	for (unsigned int i = 0; i < strlen(chars); ++i)
		sstr.erase(std::remove(sstr.begin(), sstr.end(), chars[i]), sstr.end());
	stringstream stream_p(sstr);
	stream_p.getline(buff, 10, ',');
	TA.Pixel_size_nm = atoi(buff);
	printf(" INIT PROG \u24EA PARAMS :  pixel size %g  nm\n",TA.Pixel_size_nm);

	pParm = pRoot->FirstChildElement("LambdaParameters")->FirstChildElement("LambdaParameter")->FirstChildElement("dy");
	sstr = pParm->GetText();
	for (unsigned int i = 0; i < strlen(chars); ++i)
		sstr.erase(std::remove(sstr.begin(), sstr.end(), chars[i]), sstr.end());
	stringstream streamy(sstr);
	streamy.getline(buff, 10, ',');
	TA.dy = max(atoi(buff), TA.dy);
	if (verbose)
		cout << streamy.str() << endl;
	printf(" INIT PROG \u24EA maximum number of scan points in x and y, x: %d, y:%d \n", TA.dx, TA.dy);

	/** Threads parameters
		 *
		 */
		THreadsRatio = CEILING_POS((1.0*PixZoomSquare)/THREADSVAL);
		NThreads = THreadsRatio * THREADSVAL;

		/** distrib parameters: cover all possible values of the distribution up
		 *  to the corner of the microimage included dummy pixels incremented by the pPSF size -1 to avoid counting twice the pixel
		 */
		XDistrib = (PixZoomo2+PSFZoomo2)*2+1;
		YDistrib = (PixZoomo2+PSFZoomo2)*2+1;
		YDistrib_extended = NThreads/PixZoom+PSFZoom;
		lostlines = ceil((1.0*NThreads)/PixZoom) - PixZoom;

		float tempe = XDistrib * YDistrib_extended;
		ADistrib = CEILING_POS(tempe/THREADSVAL)*THREADSVAL;


	/** SCRATCH and TILE parameters
	 *
	 */
	XTile = XSCRATCH - dxSCR;	// we do not care on x because the distribution will be zero
												// We add lostpixels  at start and end of the scratchpad
												// for "spillover" of the first and last line
	YTile = YSCRATCH - dySCR - lostlines; // in y we need the full size
	if((YTile%2)==0) YTile--;
	TA.XTileSize = (XTile * TA.Pixel_size_nm)/(1000.*pZOOM);
	TA.YTileSize = (YTile * TA.Pixel_size_nm)/(1000.*pZOOM);
	ATile = XTile * YTile;


	printf("************** DATA: PARAMETERS OF MEASUREMENT *******************\n"
			" INIT PROG \u24EA BASIC  : NThreads %d Npixel %d pZOOM %d, pPSF %d RDISTRIB %d\n", NThreads, Npixel, pZOOM,
			pPSF, RDISTRIB);
	printf(" INIT PROG \u24EA PIXEL  : Npixel %d PixZoom %d PixZoomo2 %d\n", Npixel, PixZoom, PixZoomo2);
	printf(" INIT PROG \u24EA PIXEL  : lost lines %d additional lines at the end of microimage\n", lostlines);

	printf(" INIT PROG \u24EA pPSF   : pPSF %d PSFZoom %d PSFZoomo2 %d \n", pPSF, PSFZoom, PSFZoomo2);
	printf(" INIT PROG \u24EA DISTRIB: XDistrib %d YDistrib %d YDistrib_extended %d  Size in KBytes %g ADistrib %d RDISTRIB %d\n",
											XDistrib, YDistrib, YDistrib_extended, ADistrib/1024., ADistrib, RDISTRIB);
	printf(" INIT PROG \u24EA SCRATCH: XSCRATCH %d YSCRATCH %d dxSCR %d dySCR %d\n", XSCRATCH, YSCRATCH, dxSCR, dySCR);
	printf(" INIT PROG \u24EA SCRATCH: DEL SCRATCH %d Additional pixels at start and end of SCRATCH\n", lostpixels);
	printf(" INIT PROG \u24EA TILE   : XTILE %d YTILE %d  size : XTILE:%6.3f µm YTILE %6.3f µm\n",  XTile, YTile, TA.XTileSize, TA.YTileSize);
	printf(" INIT PROG \u24EA PARAMS :  Number of threads %d Threads per batch %d number of batch %d\n\n",
	NThreads, THREADSVAL, THreadsRatio);
	printf(" INIT PROG \u23f3 Data parameters in device memory ...\n");

	printf("******************Retrieving microimages size **************\n");
	filename = resourcesdirectory + "cropped_measurements.xml";
	printf(" INIT PROG \u24EA  microimages:  %s \n", filename.c_str());
	LoadACQOK = XMLError(ACQXML.LoadFile(filename.c_str()));
	pRoot = ACQXML.FirstChildElement("Image_Contents");
	pParm = pRoot->FirstChildElement("Nb_Rows");
	if (verbose)
		printf(" INIT PROG \u24EA  Nb_Rows ");
	sstr = pParm->GetText();
	stringstream streamRows(sstr);
	streamRows.getline(buff, 10, ',');
	TA.Nb_Rows_microimages = atoi(buff);

	pParm = pRoot->FirstChildElement("Nb_Cols");
	sstr = pParm->GetText();
	stringstream streamCols(sstr);
	streamCols.getline(buff, 10, ',');
	TA.Nb_Cols_microimages = atoi(buff);
	printf(" INIT PROG \u24EA microimages Rows %d, columns in file %d and in constants %d\n\n", TA.Nb_Rows_microimages,
			TA.Nb_Cols_microimages, Npixel);

	if ((TA.Nb_Cols_microimages != TA.Nb_Rows_microimages)||(TA.Nb_Cols_microimages != Npixel)) {
		printf(" INIT PROG \u24EA non square image, Nb_Rows_microimages %d\n\n", TA.Nb_Cols_microimages);
		printf(" INIT PROG \u24EA non square image, Nb_Rows_microimages %d\n\n", TA.Nb_Cols_microimages);
		printf(" INIT PROG \u24EA Number of pixels does not fit %d\n\n", TA.Nb_Cols_microimages);
		exit(1);
	}

	filenamexml = resourcesdirectory + "reconstruction.xml";
	printf("INIT PROG \u24EA reconstruction xml:  %s \n", filenamexml.c_str());
	doc.LoadFile(filenamexml.c_str());

	TA.Nb_Rows_reconstruction = atoi(doc.FirstChildElement("Image_Contents")
			->FirstChildElement("Nb_Rows")->GetText());
	TA.Nb_Cols_reconstruction = atoi(doc.FirstChildElement("Image_Contents")
			->FirstChildElement("Nb_Cols")->GetText());
	/** Sanity check */
		printf("INIT PROG \u24EA reconstruction from tiles: Rows: %d Cols %d size %d \n",
				TA.Nb_Rows_reconstruction, TA.Nb_Cols_reconstruction, TA.reconstruction_size);

	return (dimfit);
}

