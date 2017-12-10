/*
 * constantLoop.h
 *
 *  Created on: Jul 6, 2017
 *      Author: gabriel
 */

#ifndef CONSTANTLOOP_H_
#define CONSTANTLOOP_H_

/*************General macros and variables ******************************/
#define CEILING_POS(X) ((X-(int)(X)) > 0 ? (int)(X+1) : (int)(X))

////////////////////////////////////////////////////////////////////////////////
// Constants
#define MAX_EPSILON_ERROR 5e-3f
#define TRUE 1
#define FALSE 0
#define X 0
#define Y 1
#define VERBOSE 1
#define NOVERBOSE 0
#define BUFFSIZE 80
#define SPARSE 20

// Maximum for values which cannot be determined at compile time
#define NUMLASERPOSITIONS 250000
#define MAXTILE 512
#define MAXNBDISTRIB 8
#define MAXNUMBERLASERTILE 256

/** Shortcut parameters
 *
 */
#define PixZoom (Npixel*pZOOM)// verifier
#define PixZoomSquare (PixZoom*PixZoom)
#define PixSquare (Npixel*Npixel)
#define PixZoomo2 (PixZoom/2)// verifier
#define PSFZoom (pPSF*pZOOM)
#define PSFZoomo2 (PSFZoom/2)
#define PSFZOOMSQUARE (PSFZoom*PSFZoom) // PSFZoom square
#define RdistribZoom (RDISTRIB * pZOOM)

/** Tile to SCRATCH parameters
 *
 */

#define dxSCR (RdistribZoom-1)
#define dxSCRo2 (dxSCR/2)
#define dySCR (2*(PSFZoomo2+PixZoomo2))
#define dySCRo2 (dySCR/2)

#define lostpixels (dySCRo2 -dxSCRo2)

/** Scratchpad parameters
 *
 */
#define	XSCRATCH (PixZoom + NumBankScratch * BANKNUMBER )  // to be updated
#define ASCRATCH (NSCRATCH*THREADSVAL)
#define BSCRATCH  (ASCRATCH - 2*lostpixels)
#define	YSCRATCH (BSCRATCH / XSCRATCH)

#endif /* CONSTANTLOOP_H_ */
