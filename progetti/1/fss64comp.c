/**************************************************************************************
* 
* CdL Magistrale in Ingegneria Informatica
* Corso di Architetture e Programmazione dei Sistemi di Elaborazione - a.a. 2020/21
* 
* Progetto dell'algoritmo Fish School Search 221 231 a
* in linguaggio assembly x86-64 + SSE
* 
* Fabrizio Angiulli, aprile 2019
* 
**************************************************************************************/

/*
* 
* Software necessario per l'esecuzione:
* 
*    NASM (www.nasm.us)
*    GCC (gcc.gnu.org)
* 
* entrambi sono disponibili come pacchetti software 
* installabili mediante il packaging tool del sistema 
* operativo; per esempio, su Ubuntu, mediante i comandi:
* 
*    sudo apt-get install nasm
*    sudo apt-get install gcc
* 
* potrebbe essere necessario installare le seguenti librerie:
* 
*    sudo apt-get install lib64gcc-4.8-dev (o altra versione)
*    sudo apt-get install libc6-dev-i386
* 
* Per generare il file eseguibile:
* 
* nasm -f elf64 fss64.nasm && gcc -m64 -msse -O0 -no-pie sseutils64.o fss64.o fss64c.c -o fss64c -lm && ./fss64c $pars
* 
* oppure
* 
* ./runfss64
* 
*/

#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <string.h>
#include <time.h>
#include <libgen.h>
#include <xmmintrin.h>
#include <omp.h>

#define	type		double
#define	MATRIX		type*
#define	VECTOR		type*

typedef struct {
	MATRIX x; //posizione dei pesci
	VECTOR xh; //punto associato al minimo di f, soluzione del problema
	VECTOR c; //coefficienti della funzione
	VECTOR r; //numeri casuali
	int np; //numero di pesci, quadrato del parametro np
	int d; //numero di dimensioni del data set
	int iter; //numero di iterazioni
	type stepind; //parametro stepind
	type stepvol; //parametro stepvol
	type wscale; //parametro wscale
	int display;
	int silent;
} params;

/*
* 
*	Le funzioni sono state scritte assumento che le matrici siano memorizzate 
* 	mediante un array (double*), in modo da occupare un unico blocco
* 	di memoria, ma a scelta del candidato possono essere 
* 	memorizzate mediante array di array (double**).
* 
* 	In entrambi i casi il candidato dovr� inoltre scegliere se memorizzare le
* 	matrici per righe (row-major order) o per colonne (column major-order).
*
* 	L'assunzione corrente � che le matrici siano in row-major order.
* 
*/

void* get_block(int size, int elements) { 
	return _mm_malloc(elements*size,32); 
}

void free_block(void* p) { 
	_mm_free(p);
}

MATRIX alloc_matrix(int rows, int cols) {
	return (MATRIX) get_block(sizeof(type),rows*cols);
}

void dealloc_matrix(MATRIX mat) {
	free_block(mat);
}

/*
* 
* 	load_data
* 	=========
* 
*	Legge da file una matrice di N righe
* 	e M colonne e la memorizza in un array lineare in row-major order
* 
* 	Codifica del file:
* 	primi 4 byte: numero di righe (N) --> numero intero
* 	successivi 4 byte: numero di colonne (M) --> numero intero
* 	successivi N*M*4 byte: matrix data in row-major order --> numeri doubleing-point a precisione singola
* 
*****************************************************************************
*	Se lo si ritiene opportuno, � possibile cambiare la codifica in memoria
* 	della matrice. 
*****************************************************************************
* 
*/
MATRIX load_data(char* filename, int *n, int *k) {
	FILE* fp;
	int rows, cols, status, i;
	
	fp = fopen(filename, "rb");
	
	if (fp == NULL){
		printf("'%s': bad data file name!\n", filename);
		exit(0);
	}
	
	status = fread(&cols, sizeof(int), 1, fp);
	status = fread(&rows, sizeof(int), 1, fp);
	
	MATRIX data = alloc_matrix(rows,cols);
	status = fread(data, sizeof(type), rows*cols, fp);
	fclose(fp);
	
	*n = rows;
	*k = cols;
	
	return data;
}

/*
* 	save_data
* 	=========
* 
*	Salva su file un array lineare in row-major order
*	come matrice di N righe e M colonne
* 
* 	Codifica del file:
* 	primi 4 byte: numero di righe (N) --> numero intero a 64 bit
* 	successivi 4 byte: numero di colonne (M) --> numero intero a 64 bit
* 	successivi N*M*4 byte: matrix data in row-major order --> numeri interi o doubleing-point a precisione singola
*/
void save_data(char* filename, void* X, int n, int k) {
	FILE* fp;
	int i;
	fp = fopen(filename, "wb");
	if(X != NULL){
		fwrite(&k, 4, 1, fp);
		fwrite(&n, 4, 1, fp);
		for (i = 0; i < n; i++) {
			fwrite(X, sizeof(type), k, fp);
			//printf("%i %i\n", ((int*)X)[0], ((int*)X)[1]);
			X += sizeof(type)*k;
		}
	}
	else{
		int x = 0;
		fwrite(&x, 4, 1, fp);
		fwrite(&x, 4, 1, fp);
	}
	fclose(fp);
}

// PROCEDURE ASSEMBLY
extern void func64(params* input, MATRIX xy, int i, type* esponente, type* ris);

extern void movimentoIndividuale1(params* input, int indRandom, MATRIX y,int zeri,int i);
 
extern void movimentoIndividuale2(params* input, MATRIX y,MATRIX deltaX, VECTOR deltaF,int i);
 
extern void operatoreAlimentazione(int i, VECTOR pesi, VECTOR deltaF, type min);

extern void movimentoIstintivo(int i, int d, MATRIX x, VECTOR I);

extern void calcolaI(params* input, VECTOR deltaF, MATRIX deltaX, VECTOR I);

extern void calcolaBaricentro(params* input,VECTOR baricentro, type* pesoTotale, VECTOR pesi );

extern void movimentoVolitivo(params* input, int indRandom, VECTOR baricentro, type molt, int i);

void minimo(VECTOR deltaF, int n, type* min){
    int i;
    *min=deltaF[0];
    for(i=1; i<n; i++){
        if(*min > deltaF[i])
            *min = deltaF[i];
	}
}

void inizializzazionePesi(params* input,VECTOR pesi, type* pesoTotale){
	int i;	
	type w = input->wscale/2;
	*pesoTotale = 0;
	for(i=0;i<input->np;i++){
		pesi[i] = w;
		*pesoTotale += w;
	}
}

type func(params* input, MATRIX xy, int i){
	type esponente;
	type ris;
	func64(input, xy, i, &esponente, &ris);
	return ris + exp(esponente);
}

void movimentoIndividualeA(params* input, MATRIX deltaX, VECTOR deltaF, int* indRandom, MATRIX y, int zeri){
    int i, j;
    int n = input->np;
    int d = input->d;
    MATRIX x = input->x;
    int iR = *indRandom;

    #pragma omp parallel for
    for(i=0; i<n; i++){
        movimentoIndividuale1(input, *indRandom +i*(d-zeri), y, zeri,i);        
    }
    *indRandom += n*(d-zeri);

    #pragma omp parallel for
    for(i=0; i<n-3; i+=4){
	deltaF[i] = func(input, y, i) - func(input, x, i);
	deltaF[i+1] = func(input, y, i+1) - func(input, x, i+1);
	deltaF[i+2] = func(input, y, i+2) - func(input, x, i+2);
	deltaF[i+3] = func(input, y, i+3) - func(input, x, i+3);
    } 
    #pragma omp parallel for
    for(j=n-n%4;j<n; j++)
	deltaF[j] = func(input, y, j) - func(input, x, j);
    #pragma omp parallel for
    for(i=0; i<n; i++){
        movimentoIndividuale2(input,y ,deltaX,deltaF,i);
    }
}

void operatoreAlimentazioneA(params* input, VECTOR pesi, VECTOR deltaF){
	int i,j,k;
	int n=input->np;
	type min;
	minimo(deltaF,n,&min);
	if(min!=0){
	    #pragma omp parallel for
	    for(i=0; i<n-15; i+=16){
		operatoreAlimentazione(i, pesi, deltaF,min);
		operatoreAlimentazione(i+4, pesi, deltaF,min);
		operatoreAlimentazione(i+8, pesi, deltaF,min);
		operatoreAlimentazione(i+12, pesi, deltaF,min);
	    } 
	    #pragma omp parallel for
	    for(j=n-n%16;j<n-3; j+=4){
		operatoreAlimentazione(j, pesi, deltaF,min);
	    }
	    #pragma omp parallel for
	    for(k=n-n%4;k<n; k++)
		pesi[k]=pesi[k]+(deltaF[k]/min);
	}
}

void movimentoIstintivoA(params* input, MATRIX deltaX, VECTOR deltaF, VECTOR I){
	int i, j;
	int d = input->d;
	int n = input->np;
	calcolaI(input, deltaF, deltaX, I);
	#pragma omp parallel for
	for(i=0; i<n; i++){
		movimentoIstintivo(i, d, input->x, I);
	}	
}

void movimentoVolitivoA(params* input, int* indRandom, VECTOR baricentro, type* pesoTotale, type* nuovoPesoTotale){
	int i, j;
	type molt=1;
	int n = input->np;
	int d = input->d;
	type random, distanzaEuclidea;
	type stepvol = input->stepvol;
	VECTOR r = input->r;
	MATRIX x = input->x;
	if(*nuovoPesoTotale > *pesoTotale)
		molt = -1;
	#pragma omp parallel for
	for(i=0; i<n; i++){
		movimentoVolitivo(input, *indRandom, baricentro, molt, i);
	}
	*indRandom = *indRandom + n;
	*pesoTotale = *nuovoPesoTotale;
}

void aggiornamentoParametri(params* input, type stepindInitial, type stepvolInital){
	input->stepind = input->stepind - (stepindInitial / input->iter);
	input->stepvol = input->stepvol - (stepvolInital / input->iter);
}

void trovaOttimo(params* input, int zeri){
	int i, j;
	int n = input->np;
	int d = input->d;
	MATRIX x = input->x;
	int pesceMin = 0;
	type f, fMin;
	fMin = func(input, x, 0);
	for(i=1; i<n; i++){
		f = func(input, x, i);
		if(f < fMin){
			fMin = f; 
			pesceMin = i;
		}
	}
	for(j=0; j<d-zeri; j++)
		input->xh[j] = x[d*pesceMin+j];
}

void fss (params* input,int zeri){
	int it = 0;
	int indRandom = 0;

	MATRIX y = (MATRIX) get_block(sizeof(type), input->np*input->d);
	MATRIX deltaX = (MATRIX) get_block(sizeof(type), input->np*input->d);
    	VECTOR deltaF = (VECTOR) get_block(sizeof(type), input->np);

	VECTOR I = (VECTOR) get_block(sizeof(type), input->d);
	
    	VECTOR baricentro = (VECTOR) get_block(sizeof(type),input->d);
	VECTOR pesi = (VECTOR) get_block(sizeof(type), input->np);
	type pesoTotale;
	type nuovoPesoTotale;

	input->xh = (VECTOR) get_block(sizeof(type), input->d-zeri);

	type stepindInital = input->stepind;
	type stepvolInital = input->stepvol;
	type min;
	inizializzazionePesi(input, pesi, &pesoTotale);
	for(it=0; it<input->iter; it++){
		movimentoIndividualeA(input, deltaX, deltaF, &indRandom, y, zeri);
		operatoreAlimentazioneA(input, pesi, deltaF);
		movimentoIstintivoA(input, deltaX, deltaF, I);
		calcolaBaricentro(input, baricentro, &nuovoPesoTotale, pesi);	
		movimentoVolitivoA(input, &indRandom, baricentro, &pesoTotale, &nuovoPesoTotale);
		aggiornamentoParametri(input, stepindInital, stepvolInital);
	}
	trovaOttimo(input, zeri);
}

void aggiungiResto(params* input, int resto){
	int i, j;
	resto = 4-resto;
	input->d = input->d + resto;
	MATRIX nuovaX = (MATRIX) get_block(sizeof(type), input->np*input->d);
	for(i=0; i<input->np; i++)
		for(j=0; j<input->d; j++)
			if(j<input->d-resto)
				nuovaX[i*input->d+j] = input->x[i*(input->d-resto)+j];
			else
				nuovaX[i*input->d+j] = 0;
	input->x = nuovaX; 
}


int main(int argc, char** argv) {

	char fname[256];
	char* coefffilename = NULL;
	char* randfilename = NULL;
	char* xfilename = NULL;
	int i, j, k;
	clock_t t;
	double time;
	
	//
	// Imposta i valori di default dei parametri
	//

	params* input = malloc(sizeof(params));

	input->x = NULL;
	input->xh = NULL;
	input->c = NULL;
	input->r = NULL;
	input->np = 25;
	input->d = 2;
	input->iter = 350;
	input->stepind = 1;
	input->stepvol = 0.1;
	input->wscale = 10;
	
	input->silent = 0;
	input->display = 0;

	//
	// Visualizza la sintassi del passaggio dei parametri da riga comandi
	//

	if(argc <= 1){
		printf("%s -c <c> -r <r> -x <x> -np <np> -si <stepind> -sv <stepvol> -w <wscale> -it <itmax> [-s] [-d]\n", argv[0]);
		printf("\nParameters:\n");
		printf("\tc: il nome del file ds2 contenente i coefficienti\n");
		printf("\tr: il nome del file ds2 contenente i numeri casuali\n");
		printf("\tx: il nome del file ds2 contenente le posizioni iniziali dei pesci\n");
		printf("\tnp: il numero di pesci, default 25\n");
		printf("\tstepind: valore iniziale del parametro per il movimento individuale, default 1\n");
		printf("\tstepvol: valore iniziale del parametro per il movimento volitivo, default 0.1\n");
		printf("\twscale: valore iniziale del peso, default 10\n");
		printf("\titmax: numero di iterazioni, default 350\n");
		printf("\nOptions:\n");
		printf("\t-s: modo silenzioso, nessuna stampa, default 0 - false\n");
		printf("\t-d: stampa a video i risultati, default 0 - false\n");
		exit(0);
	}

	//
	// Legge i valori dei parametri da riga comandi
	//

	int par = 1;
	while (par < argc) {
		if (strcmp(argv[par],"-s") == 0) {
			input->silent = 1;
			par++;
		} else if (strcmp(argv[par],"-d") == 0) {
			input->display = 1;
			par++;
		} else if (strcmp(argv[par],"-c") == 0) {
			par++;
			if (par >= argc) {
				printf("Missing coefficient file name!\n");
				exit(1);
			}
			coefffilename = argv[par];
			par++;
		} else if (strcmp(argv[par],"-r") == 0) {
			par++;
			if (par >= argc) {
				printf("Missing random numbers file name!\n");
				exit(1);
			}
			randfilename = argv[par];
			par++;
		} else if (strcmp(argv[par],"-x") == 0) {
			par++;
			if (par >= argc) {
				printf("Missing initial fish position file name!\n");
				exit(1);
			}
			xfilename = argv[par];
			par++;
		} else if (strcmp(argv[par],"-np") == 0) {
			par++;
			if (par >= argc) {
				printf("Missing np value!\n");
				exit(1);
			}
			input->np = atoi(argv[par]);
			par++;
		} else if (strcmp(argv[par],"-si") == 0) {
			par++;
			if (par >= argc) {
				printf("Missing stepind value!\n");
				exit(1);
			}
			input->stepind = atof(argv[par]);
			par++;
		} else if (strcmp(argv[par],"-sv") == 0) {
			par++;
			if (par >= argc) {
				printf("Missing stepvol value!\n");
				exit(1);
			}
			input->stepvol = atof(argv[par]);
			par++;
		} else if (strcmp(argv[par],"-w") == 0) {
			par++;
			if (par >= argc) {
				printf("Missing wscale value!\n");
				exit(1);
			}
			input->wscale = atof(argv[par]);
			par++;
		} else if (strcmp(argv[par],"-it") == 0) {
			par++;
			if (par >= argc) {
				printf("Missing iter value!\n");
				exit(1);
			}
			input->iter = atoi(argv[par]);
			par++;
		} else{
			printf("WARNING: unrecognized parameter '%s'!\n",argv[par]);
			par++;
		}
	}

	//
	// Legge i dati e verifica la correttezza dei parametri
	//
	

	if(coefffilename == NULL || strlen(coefffilename) == 0){
		printf("Missing coefficient file name!\n");
		exit(1);
	}

	if(randfilename == NULL || strlen(randfilename) == 0){
		printf("Missing random numbers file name!\n");
		exit(1);
	}

	if(xfilename == NULL || strlen(xfilename) == 0){
		printf("Missing initial fish position file name!\n");
		exit(1);
	}


	int x,y;
	input->c = load_data(coefffilename, &input->d, &y);
	input->r = load_data(randfilename, &x, &y);
	input->x = load_data(xfilename, &x, &y);


	if(input->np < 0){
		printf("Invalid value of np parameter!\n");
		exit(1);
	}

	if(input->stepind < 0){
		printf("Invalid value of si parameter!\n");
		exit(1);
	}

	if(input->stepvol < 0){
		printf("Invalid value of sv parameter!\n");
		exit(1);
	}

	if(input->wscale < 0){
		printf("Invalid value of w parameter!\n");
		exit(1);
	}

	if(input->iter < 0){
		printf("Invalid value of it parameter!\n");
		exit(1);
	}

	//
	// Visualizza il valore dei parametri
	//
	
	if(!input->silent){
		printf("Coefficient file name: '%s'\n", coefffilename);
		printf("Random numbers file name: '%s'\n", randfilename);
		printf("Initial fish position file name: '%s'\n", xfilename);
		printf("Dimensions: %d\n", input->d);
		printf("Number of fishes [np]: %d\n", input->np);
		printf("Individual step [si]: %f\n", input->stepind);
		printf("Volitive step [sv]: %f\n", input->stepvol);
		printf("Weight scale [w]: %f\n", input->wscale);
		printf("Number of iterations [it]: %d\n", input->iter);
	}

	int resto = input->d%4;
	if(resto!=0){
		aggiungiResto(input, resto);
		resto=4-resto;
	}
	
	//
	// Fish School Search
	//

	t = clock();
	fss(input,resto);
	t = clock() - t;
	time = ((double)t)/CLOCKS_PER_SEC;

	if(!input->silent)
		printf("FSS time = %.3f secs\n", time);
	else
		printf("%.3f\n", time);

	//
	// Salva il risultato di xh
	//
	input->d = input->d-resto;
	sprintf(fname, "xh64_%d_%d_%d.ds2", input->d, input->np, input->iter);
	save_data(fname, input->xh, 1, input->d);
	if(input->display){
		if(input->xh == NULL)
			printf("xh: NULL\n");
		else{
			printf("xh: [");
			for(i=0; i<input->d-1; i++)
				printf("%f,", input->xh[i]);
			printf("%f]\n", input->xh[i]);
		}
	}

	if(!input->silent)
		printf("\nDone.\n");

	return 0;
}

