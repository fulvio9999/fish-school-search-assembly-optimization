; ---------------------------------------------------------
; Regressione con istruzioni SSE a 32 bit
; ---------------------------------------------------------
; F. Angiulli
; 23/11/2017
;

;
; Software necessario per l'esecuzione:
;
;     NASM (www.nasm.us)
;     GCC (gcc.gnu.org)
;
; entrambi sono disponibili come pacchetti software 
; installabili mediante il packaging tool del sistema 
; operativo; per esempio, su Ubuntu, mediante i comandi:
;
;     sudo apt-get install nasm
;     sudo apt-get install gcc
;
; potrebbe essere necessario installare le seguenti librerie:
;
;     sudo apt-get install lib32gcc-4.8-dev (o altra versione)
;     sudo apt-get install libc6-dev-i386
;
; Per generare file oggetto:
;
;     nasm -f elf32 fss32.nasm 
;
%include "sseutils32.nasm"

section .data			; Sezione contenente dati inizializzati
	align 16
	uno 			dd 		1.0,1.0,1.0,1.0
	align 16
	due 			dd 		2.0,2.0,2.0,2.0
	align 16
	zero 			dd 		0.0,0.0,0.0,0.0
	align 16
	menoUno			dd		-1.0,-1.0,-1.0,-1.0

section .bss			; Sezione contenente dati non inizializzati
	ris resd 1
	ris2 resd 4

section .text			; Sezione contenente il codice macchina
x				equ		0
xh				equ		4
c				equ		8
r				equ		12
np				equ		16
d				equ		20
iter				equ		24
stepind				equ		28
stepvol				equ		32
wscale				equ		36

dim 				equ		4
p 				equ		4
UNROLL 				equ		4

; ----------------------------------------------------------
; macro per l'allocazione dinamica della memoria
;
;	getmem	<size>,<elements>
;
; alloca un'area di memoria di <size>*<elements> bytes
; (allineata a 16 bytes) e restituisce in EAX
; l'indirizzo del primo bytes del blocco allocato
; (funziona mediante chiamata a funzione C, per cui
; altri registri potrebbero essere modificati)
;
;	fremem	<address>
;
; dealloca l'area di memoria che ha inizio dall'indirizzo
; <address> precedentemente allocata con getmem
; (funziona mediante chiamata a funzione C, per cui
; altri registri potrebbero essere modificati)

extern get_block
extern free_block

%macro	getmem	2
	mov	eax, %1
	push	eax
	mov	eax, %2
	push	eax
	call	get_block
	add	esp, 8
%endmacro

%macro	fremem	1
	push	%1
	call	free_block
	add	esp, 4
%endmacro

; ------------------------------------------------------------
; Funzioni
; ------------------------------------------------------------

global movimentoIndividuale1:
 
input                equ        8
indRandom            equ        12
i                    equ        16
matrixy                equ        20
zeri                    equ        24
 

movimentoIndividuale1:
        ; ------------------------------------------------------------
        ; Sequenza di ingresso nella funzione
        ; ------------------------------------------------------------
        push        ebp        ; salva il Base Pointer
        mov        ebp, esp    ; il Base Pointer punta al Record di Attivazione corrente
        push        ebx        ; salva i registri da preservare
        push        esi
        push        edi
        ; ------------------------------------------------------------
        ; legge i parametri dal Record di Attivazione corrente
        ; ------------------------------------------------------------
        MOV EAX, [EBP+input]
        MOV ECX, [EBP+indRandom]

        XOR EDI,EDI; J=0
        MOV ESI,[EBP+i]

        MOV EDX,[EAX+d]
        SUB EDX,p*UNROLL

 
loopj:    CMP EDI,EDX;j<d-16; 
        JGE jzeri
        ;---CASO J<D-4
        MOV EBX,[EAX+r]
        MOVUPS XMM0, [EBX+ECX*dim]
        MOVUPS XMM1, [EBX+ECX*dim+1*UNROLL*dim]
        MOVUPS XMM2, [EBX+ECX*dim+2*UNROLL*dim]
        MOVUPS XMM3, [EBX+ECX*dim+3*UNROLL*dim]

        MULPS XMM0, [due]
        MULPS XMM1, [due]
        MULPS XMM2, [due]
        MULPS XMM3, [due]

        SUBPS XMM0,[uno]
        SUBPS XMM1,[uno]
        SUBPS XMM2,[uno]
        SUBPS XMM3,[uno]

        MOVSS XMM7, [EAX+stepind]; XMM7=stepind
        SHUFPS XMM7,XMM7,0

        MULPS XMM0,XMM7; XMM0 =(2 * R[IndRandom]  - 1) * stepind
        MULPS XMM1,XMM7; 
        MULPS XMM2,XMM7; 
        MULPS XMM3,XMM7; 

        MOV EDX,ESI; edx=i;
        IMUL EDX,[EAX+d];edx=i*d
        ADD EDX,EDI;edx=i*d+j
        MOV EBX,[EAX+x]



        ; XMM4 =X[I*D+J] VETTORIZZATO
        MOVAPS XMM4, [EBX+EDX*dim]
        MOVAPS XMM5, [EBX+EDX*dim+1*UNROLL*dim]
        MOVAPS XMM6, [EBX+EDX*dim+2*UNROLL*dim]
        MOVAPS XMM7, [EBX+EDX*dim+3*UNROLL*dim]

        ADDPS XMM0,XMM4
        ADDPS XMM1,XMM5
        ADDPS XMM2,XMM6
        ADDPS XMM3,XMM7

        MOV EBX,[EBP+matrixy]

        MOVAPS  [EBX+EDX*dim], XMM0
        MOVAPS  [EBX+EDX*dim+1*UNROLL*dim], XMM1
        MOVAPS  [EBX+EDX*dim+2*UNROLL*dim], XMM2
        MOVAPS  [EBX+EDX*dim+3*UNROLL*dim], XMM3
        ADD ECX,p*UNROLL
        JMP next

        ;---FINE CASO J<D-4
        ;---CASO J>=D-4
jzeri:        ADD EDX, p*UNROLL
        MOVSS XMM7, [EAX+stepind]; 
        SUB EDX, [EBP+zeri]
loopzeri:    CMP EDI,EDX;j<d-zeri; 
        JGE jpadding
        ;---CASO J<D-ZERI
        MOV EBX,[EAX+r]
        MOVSS XMM0, [EBX+ECX*dim]
        MULSS XMM0, [due]
        SUBSS XMM0,[uno]
        MULSS XMM0,XMM7
        MOV EBX,[EAX+x]
        MOV EDX,ESI; edx=i;
        IMUL EDX,[EAX+d];edx=i*d
        ADD EDX,EDI;edx=i*d+j
        MOVSS XMM1,[EBX+EDX*dim]
        ADDSS XMM0,XMM1
        MOV EBX,[EBP+matrixy]
        MOVSS [EBX+EDX*dim],XMM0
        INC ECX
        JMP nextpadd
        ;---FINE CASO J<D-ZERI
        ;---CASO J>=D-ZERI
jpadding:    MOVSS XMM0,[zero]
        MOV EBX,[EBP+matrixy]
        MOV EDX,ESI; edx=i;
        IMUL EDX,[EAX+d];edx=i*d
        ADD EDX,EDI;edx=i*d+j
        MOVSS [EBX+EDX*dim],XMM0
        ;---FINE CASO J>=D-ZERI
nextpadd:MOV EDX,[EAX+d]
        INC EDI
        CMP EDI,EDX
        JGE endloopj
        SUB EDX, [EBP+zeri]
        JMP loopzeri
        ;---FINE CASO J>=D-ZERI

next:    MOV EDX,[EAX+d]
        SUB EDX,p*UNROLL
        ADD EDI,p*UNROLL
        JMP loopj
        ;---FINE CASO J<D
        ;------------------------------------------------------------
        ; Sequenza di uscita dalla funzione
        ; ------------------------------------------------------------
 
endloopj:    pop    edi        ; ripristina i registri da preservare
        pop    esi
        pop    ebx
        mov    esp, ebp    ; ripristina lo Stack Pointer
        pop    ebp        ; ripristina il Base Pointer
        ret            ; torna alla funzione C chiamante

global movimentoIndividuale2:
 
input            equ        8
ymatrix            equ        12
deltaX            equ        16
deltaF            equ        20
i2                equ        24
 
msg db 'stampa',0
nl db 10,0

movimentoIndividuale2:
        ; ------------------------------------------------------------
        ; Sequenza di ingresso nella funzione
        ; ------------------------------------------------------------
        push        ebp        ; salva il Base Pointer
        mov        ebp, esp    ; il Base Pointer punta al Record di Attivazione corrente
        push        ebx        ; salva i registri da preservare
        push        esi
        push        edi
        ; ------------------------------------------------------------
        ; legge i parametri dal Record di Attivazione corrente
        ; ------------------------------------------------------------
        MOV EAX, [EBP+ input]
        MOV ESI, [EBP +i2]        
        MOV EDI,0
        MOV EDX,[EAX+d]
        SUB EDX,p*UNROLL-1
        MOV EBX,[EBP+deltaF]
        MOV ECX, [EBX+ESI*dim]; ecx=DELTAF[I]
        CMP ECX, 0
        JGE else

forj:  CMP EDI,EDX
        JGE restoloop
        MOV ECX,ESI
        IMUL ECX,[EAX+d]
        ADD ECX,EDI

        MOV EBX, [EBP+ymatrix]

        MOVAPS XMM0, [EBX+ECX*dim]
        MOVAPS XMM1, [EBX+ECX*dim+1*UNROLL*dim]
        MOVAPS XMM2, [EBX+ECX*dim+2*UNROLL*dim]
        MOVAPS XMM3, [EBX+ECX*dim+3*UNROLL*dim]

        MOV EBX, [EAX+x]

        MOVAPS XMM4, [EBX+ECX*dim]
        MOVAPS XMM5, [EBX+ECX*dim+1*UNROLL*dim]
        MOVAPS XMM6, [EBX+ECX*dim+2*UNROLL*dim]
        MOVAPS XMM7, [EBX+ECX*dim+3*UNROLL*dim]

        MOVAPS [EBX+ECX*dim],XMM0
        MOVAPS [EBX+ECX*dim+1*UNROLL*dim],XMM1
        MOVAPS [EBX+ECX*dim+2*UNROLL*dim],XMM2
        MOVAPS [EBX+ECX*dim+3*UNROLL*dim],XMM3

        SUBPS XMM0,XMM4
        SUBPS XMM1,XMM5
        SUBPS XMM2,XMM6
        SUBPS XMM3,XMM7

        MOV EBX, [EBP+deltaX]

        MOVAPS [EBX+ECX*dim],XMM0
        MOVAPS [EBX+ECX*dim+1*UNROLL*dim],XMM1
        MOVAPS [EBX+ECX*dim+2*UNROLL*dim],XMM2
        MOVAPS [EBX+ECX*dim+3*UNROLL*dim],XMM3

        ADD EDI,p*UNROLL
        JMP forj

restoloop:    ADD EDX,p*UNROLL-1
forresto    CMP EDI,EDX
        JGE endloopje
        MOV ECX,ESI
        IMUL ECX,EDX
        ADD ECX,EDI
        MOV EBX, [EBP+ymatrix]
        MOVSS XMM1, [EBX+ECX*dim]
        MOV EBX, [EAX+x]
        MOVSS XMM2, [EBX+ECX*dim]
        MOVSS [EBX+ECX*dim],XMM1
        SUBSS XMM1,XMM2
        MOV EBX, [EBP+deltaX]
        MOVSS [EBX+ECX*dim],XMM1
        ADD EDI,1
        JMP forresto        

else: MOVSS XMM7,[zero]        
        MOVSS [EBX+ESI*dim],XMM7    
loopje:    CMP EDI,EDX
        JGE restoe
        MOV EBX, [EBP+deltaX]
        MOV ECX,ESI
        IMUL ECX,[EAX+d]
        ADD ECX,EDI
        XORPS XMM7, XMM7
	
        MOVAPS [EBX+ECX*dim],XMM7
        MOVAPS [EBX+ECX*dim+1*UNROLL*dim],XMM7
        MOVAPS [EBX+ECX*dim+2*UNROLL*dim],XMM7
        MOVAPS [EBX+ECX*dim+3*UNROLL*dim],XMM7
        ADD EDI, p*UNROLL
        JMP loopje

restoe:    ADD EDX,p*UNROLL-1
loopjer:    CMP EDI,EDX
        JGE endloopje
        MOV EBX, [EBP+deltaX]
        MOV ECX,ESI
        IMUL ECX,EDX
        ADD ECX,EDI
        MOVSS XMM7,[zero]        
        MOVSS [EBX+ECX*dim],XMM7
        ADD EDI, 1
        JMP loopjer
        ; ------------------------------------------------------------
        ; Sequenza di uscita dalla funzione
        ; ------------------------------------------------------------
endloopje:pop    edi        ; ripristina i registri da preservare
        pop    esi
        pop    ebx
        mov    esp, ebp    ; ripristina lo Stack Pointer
        pop    ebp        ; ripristina il Base Pointer
        ret            ; torna alla funzione C chiamante



global operatoreAlimentazione:
 
i3            equ        8
pesi                equ        12
delta            equ        16
min                equ        20
 

operatoreAlimentazione:
        ; ------------------------------------------------------------
        ; Sequenza di ingresso nella funzione
        ; ------------------------------------------------------------
        push        ebp        ; salva il Base Pointer
        mov        ebp, esp    ; il Base Pointer punta al Record di Attivazione corrente
        push        ebx        ; salva i registri da preservare
        push        esi
        push        edi
        ; ------------------------------------------------------------
        ; legge i parametri dal Record di Attivazione corrente
        ; ------------------------------------------------------------
        MOV EAX, [EBP+i3]
        MOV EBX, [EBP+pesi]
        MOV EDX, [EBP+delta]

        MOVSS XMM7, [EBP+min]
        SHUFPS XMM7,XMM7,0

        MOVAPS XMM0,[EDX+EAX*dim]
        DIVPS XMM0,XMM7

        MOVAPS XMM1,[EBX+EAX*dim]

        ADDPS XMM0,XMM1

        MOVAPS [EBX+EAX*dim],XMM0

        pop    edi        ; ripristina i registri da preservare
        pop    esi
        pop    ebx
        mov    esp, ebp    ; ripristina lo Stack Pointer
        pop    ebp        ; ripristina il Base Pointer
        ret            ; torna alla funzione C chiamante

		

global movimentoIstintivo:

ii				equ		8
dimensione			equ		12
XX				equ		16
Iv				equ		20



movimentoIstintivo:
		; ------------------------------------------------------------
		; Sequenza di ingresso nella funzione
		; ------------------------------------------------------------
		push		ebp		; salva il Base Pointer
		mov			ebp, esp	; il Base Pointer punta al Record di Attivazione corrente
		push		ebx		; salva i registri da preservare
		push		esi
		push		edi
		; ------------------------------------------------------------
		; legge i parametri dal Record di Attivazione corrente
		; ------------------------------------------------------------
	
		; elaborazione
		mov EAX,[EBP+XX]		
		imul EBX,[EBP+ii], dim			
		
		mov ECX, 0  		;j=0

forjs:		imul ESI,[EBP+dimensione],dim
		sub ESI,dim*p*(UNROLL-1)
		cmp ECX,ESI
		jge forjRest
					
		
		mov EDI, [EBP+dimensione]	;EDI= d
		imul EDI, EBX		;EDI = d*i
		add EDI,ECX		;EDI = d*i +j
		
		movaps XMM0, [EAX + EDI]
		movaps XMM1, [EAX + EDI+p*dim]
		movaps XMM2, [EAX + EDI+2*p*dim]
		movaps XMM3, [EAX + EDI+3*p*dim]
			
		mov ESI,[EBP + Iv]
		
		movaps XMM4,[ESI+ECX]		;XMM0=x[d*i+j]+I[j]
		movaps XMM5,[ESI+ECX+p*dim]
		movaps XMM6,[ESI+ECX+2*p*dim]
		movaps XMM7,[ESI+ECX+3*p*dim] 
		
		addps XMM0,XMM4		;XMM0=x[d*i+j]+I[j]
		addps XMM1,XMM5
		addps XMM2,XMM6
		addps XMM3,XMM7
		
		movaps [EAX + EDI],XMM0
		movaps [EAX + EDI+p*dim],XMM1
		movaps [EAX + EDI+2*p*dim],XMM2
		movaps [EAX + EDI+3*p*dim],XMM3
		
		add ECX,p*dim*UNROLL
		jmp forjs
		
forjRest:	mov EDI,[EBP+dimensione]
		imul ESI,EDI, dim
		cmp ECX,ESI
		jge endForJ 		
	
		
		mov EDI, [EBP+dimensione]	;EDI= d
		imul EDI, EBX		;EDI = d*i
		add EDI,ECX		;EDI = d*i +j
		
		movaps XMM0, [EAX + EDI]
			
		mov ESI,[EBP + Iv]
		movaps	XMM1,[ESI+ECX]
		
		addps XMM0,XMM1		;XMM0=x[d*i+j]+I[j]
		
		movaps [EAX + EDI],XMM0
		
		add ECX,p*dim
		jmp forjRest		
		
endForJ:
	
		
		; ------------------------------------------------------------
		; Sequenza di uscita dalla funzione
		; ------------------------------------------------------------

		pop	edi		; ripristina i registri da preservare
		pop	esi
		pop	ebx
		mov	esp, ebp	; ripristina lo Stack Pointer
		pop	ebp		; ripristina il Base Pointer
		ret			; torna alla funzione C chiamante

		
global calcolaI:

input				equ		8
I				equ		12
deltaFs				equ		16
deltaXs				equ		20


calcolaI:
		; ------------------------------------------------------------
		; Sequenza di ingresso nella funzione
		; ------------------------------------------------------------
		push ebp ; salva il Base Pointer
		mov ebp, esp ; il Base Pointer punta al Record di Attivazione corrente
		push ebx ; salva i registri da preservare
		push esi
		push edi
		; ------------------------------------------------------------
		; legge i parametri dal Record di Attivazione corrente
		; ------------------------------------------------------------

		; elaborazione
		mov 	EAX, [EBP+input]
		xorps	XMM7,XMM7		;XMM7=somma=0
		mov 	EBX, [EBP+I]		;EBX=&I[0]
		
		mov 	EDX,0			;j=0
		
			
forj21:		imul ESI,[EAX+d],dim
		sub ESI,dim*p*(UNROLL-1)
		cmp EDX,ESI
		jge forj21Rest		

		
		xorps 	XMM1,XMM1		;I[j]=0
		xorps 	XMM2,XMM2
		xorps 	XMM3,XMM3
		xorps 	XMM4,XMM4
		movaps 	[EBX+EDX],XMM1
		movaps 	[EBX+EDX+p*dim],XMM2
		movaps 	[EBX+EDX+2*p*dim],XMM3
		movaps 	[EBX+EDX+3*p*dim],XMM4
		
		add 	EDX,p*UNROLL*dim	;j++
		jmp	forj21

forj21Rest:	mov EDI,[EAX+d]
		imul ESI,EDI,dim
		cmp EDX,ESI
		jge endForJ21				
		xorps 	XMM1,XMM1
		
		movaps 	[EBX+EDX],XMM1
		
		add 	EDX,dim*p	;j++
		jmp	forj21Rest

		
endForJ21:	mov 	ECX,0			;i=0
		

fori2:		mov 	EDX,0 		 	;j=0
		mov 	ESI,[EBP+deltaFs]	;EBX=&deltaF[0]
		
		movss 	XMM5,[ESI+ECX]		;XMM5=deltaF[i]
		
		
		addss 	XMM7,XMM5		;somma+=deltaF[i]
		shufps	XMM5,XMM5,0
		
forj22:		imul ESI,[EAX+d],dim
		sub ESI,dim*p*(UNROLL-1)
		cmp EDX,ESI
		jge forj22Rest
		
		mov 	ESI, [EBP+deltaXs]
		
		mov EDI,[EAX+d]
		
		imul 	EDI,ECX			;EDI = d*i
		add 	EDI,EDX			;EDI = d*i +j
		 	
		movaps 	XMM0,[ESI+EDI]		;XMM0=deltaX[d*i+j]
		movaps 	XMM1,[ESI+EDI+p*dim]
		movaps 	XMM3,[ESI+EDI+2*p*dim]
		movaps 	XMM4,[ESI+EDI+3*p*dim]
		
		mulps 	XMM0,XMM5		;deltaX[d*i+j]*deltaF[i]
		mulps	XMM1,XMM5
		mulps	XMM3,XMM5
		mulps	XMM4,XMM5
		
		
		addps	XMM0,[EBX+EDX]		;I[j]+deltaX[d*i+j]*deltaF[i]
		addps	XMM1,[EBX+EDX+p*dim]
		addps	XMM3,[EBX+EDX+2*p*dim]
		addps	XMM4,[EBX+EDX+3*p*dim]
		
		movaps 	[EBX+EDX],XMM0
		movaps 	[EBX+EDX+p*dim],XMM1
		movaps 	[EBX+EDX+p*2*dim],XMM3
		movaps 	[EBX+EDX+p*3*dim],XMM4
		
		add EDX,p*UNROLL*dim
		jmp	forj22
		
forj22Rest:	mov EDI,[EAX+d]
		imul ESI,EDI,dim
		cmp EDX,ESI
		jge endForJ22
			
		mov 	ESI, [EBP+deltaXs]
		
		imul 	EDI, ECX		;EDI = d*i
		add 	EDI,EDX			;EDI = d*i +j
		 	
		movaps 	XMM0,[ESI+EDI]		;XMM0=deltaX[d*i+j]
		
		
		mulps 	XMM0,XMM5			;deltaX[d*i+j]*deltaF[i]
		addps	XMM0,[EBX+EDX]		;I[j]+deltaX[d*i+j]*deltaF[i]
		
		movaps 	[EBX+EDX],XMM0
		
		add EDX,p*dim
		jmp forj22Rest		
		
endForJ22:	add ECX,dim
		
		imul 	EDI, [EAX+np],dim
		cmp 	ECX,EDI
		JL	fori2
		
		
		mov 	EDX,0			;j=0
		shufps 	XMM7,XMM7,0

		mov 	ESI,[zero]
		movss 	[ris],XMM7
		mov 	EDI,[ris]
		cmp	EDI,ESI
		JE	endForJ23
		
forj23:		imul ESI,[EAX+d],dim
		sub ESI,dim*p*(UNROLL-1)
		cmp EDX,ESI
		jge forj23Rest
				
		movaps 	XMM0,[EBX+EDX]		;XMM1=I[j]
		movaps 	XMM1,[EBX+EDX+p*dim]	
		movaps 	XMM3,[EBX+EDX+2*p*dim]
		movaps 	XMM4,[EBX+EDX+3*p*dim]		
		
		divps	XMM0,XMM7
		divps	XMM1,XMM7
		divps	XMM3,XMM7
		divps	XMM4,XMM7
		
		movaps 	[EBX+EDX],XMM0
		movaps 	[EBX+EDX+p*dim],XMM1
		movaps 	[EBX+EDX+2*p*dim],XMM3
		movaps 	[EBX+EDX+3*p*dim],XMM4
		
		add EDX,p*UNROLL*dim		;j++
		jmp	forj23
		
forj23Rest:	mov EDI,[EAX+d]
		imul ESI,EDI,dim
		cmp EDX,ESI
		jge endForJ23	

		movaps 	XMM0,[EBX+EDX]		;XMM1=I[j]
		
		divps	XMM0,XMM7
		
		movaps 	[EBX+EDX],XMM0
		
		add EDX,p*dim		;j++		
		jmp	forj23Rest		


endForJ23:
		
		; ------------------------------------------------------------
		; Sequenza di uscita dalla funzione
		; ------------------------------------------------------------

		pop	edi		; ripristina i registri da preservare
		pop	esi
		pop	ebx
		mov	esp, ebp	; ripristina lo Stack Pointer
		pop	ebp		; ripristina il Base Pointer
		ret			; torna alla funzione C chiamante


		
global calcolaBaricentro:

baricentros			equ		8
pesototale			equ		12
pesis				equ		16
inputs				equ		20

calcolaBaricentro:
		; ------------------------------------------------------------
		; Sequenza di ingresso nella funzione
		; ------------------------------------------------------------
		push		ebp		; salva il Base Pointer
		mov		ebp, esp	; il Base Pointer punta al Record di Attivazione corrente
		push		ebx		; salva i registri da preservare
		push		esi
		push		edi
		; ------------------------------------------------------------
		; legge i parametri dal Record di Attivazione corrente
		; ------------------------------------------------------------
	
		; elaborazione
		mov 	EAX, [EBP+inputs]
		xorps	XMM7,XMM7			;XMM7=pesototale=0
		mov 	EBX, [EBP+baricentros]		;EBX=&baricentro[0]
		
		mov 	EDX,0			;j=0	
forj31:		imul ESI,[EAX+d],dim
		sub ESI,dim*p*(UNROLL-1)
		cmp EDX,ESI
		jge forj31Rest

		xorps 	XMM1,XMM1		;baricentro[j]=0
		
		movaps 	[EBX+EDX],XMM1
		movaps 	[EBX+EDX+p*dim],XMM1
		movaps 	[EBX+EDX+2*p*dim],XMM1
		movaps 	[EBX+EDX+p*3*dim],XMM1
		
		add 	EDX,p*UNROLL*dim			;j++
		jmp	forj31
		
forj31Rest:	mov EDI,[EAX+d]
		imul ESI,EDI,dim
		cmp EDX,ESI
		jge endForJ31	
		
		xorps 	XMM1,XMM1		;baricentro[j]=0
		movaps 	[EBX+EDX],XMM1
		
		add 	EDX,p*dim			; (j<d*dim)?
		jmp	forj31Rest		
		
endForJ31:	mov 	ECX,0			;i=0

fori3:		mov 	EDX,0 		 	;j=0
		mov 	ESI,[EBP+pesis]		;EBX=&pesi[0]
		
		movss 	XMM5,[ESI+ECX]		;XMM3=pesi[i]
		addss 	XMM7,XMM5		;pesototale+=pesi[i]
		
		shufps	XMM5,XMM5,0
		
forj32:		imul ESI,[EAX+d],dim
		sub ESI,dim*p*(UNROLL-1)
		cmp EDX,ESI
		jge forj32Rest		

		mov 	EDI,[EAX+d]
		mov 	ESI, [EAX+x]		;XMM1=&x[0][0]
		
		imul 	EDI, ECX		;EDI = d*i
		add 	EDI,EDX			;EDI = d*i +j
		 	
		movaps 	XMM0,[ESI+EDI]		;XMM0=x[d*i+j]
		movaps 	XMM1,[ESI+EDI+p*dim]
		movaps 	XMM2,[ESI+EDI+2*p*dim]
		movaps 	XMM3,[ESI+EDI+3*p*dim]
		
		mulps 	XMM0,XMM5		;x[d*i+j]*pesi[i]
		mulps 	XMM1,XMM5
		mulps 	XMM2,XMM5
		mulps 	XMM3,XMM5
		
		addps	XMM0,[EBX+EDX]		;baricentro[j]+x[d*i+j]*pesi[i]
		addps	XMM1,[EBX+EDX+p*dim]
		addps	XMM2,[EBX+EDX+2*p*dim]
		addps	XMM3,[EBX+EDX+3*p*dim]
		
		movaps	[EBX+EDX],XMM0
		movaps 	[EBX+EDX+p*dim],XMM1
		movaps 	[EBX+EDX+2*p*dim],XMM2
		movaps 	[EBX+EDX+3*p*dim],XMM3
		
		add 	EDX,p*UNROLL*dim
		jmp 	forj32

forj32Rest:	mov EDI,[EAX+d]
		imul ESI,EDI,dim
		cmp EDX,ESI
		jge endForJ32		

		mov 	EDI,[EAX+d]
		mov 	ESI, [EAX+x]		;XMM1=&x[0][0]
		
		imul 	EDI, ECX		;EDI = d*i
		add 	EDI,EDX			;EDI = d*i +j
		 	
		movaps 	XMM0,[ESI+EDI]		;XMM0=x[d*i+j]
		mulps 	XMM0,XMM5		;x[d*i+j]*pesi[i]
		addps	XMM0,[EBX+EDX]		;baricentro[j]+x[d*i+j]*pesi[i]
		movaps	[EBX+EDX],XMM0
		
		add 	EDX,p*dim
		jmp 	forj32Rest
				
endForJ32:	add 	ECX,dim
		mov 	EDI, [EAX+np]
		imul 	ESI,EDI,dim
		cmp 	ECX,ESI
		jb 	fori3
		
		mov 	EDX,0			;j=0
		shufps 	XMM7,XMM7,0
forj33:		imul ESI,[EAX+d],dim
		sub ESI,dim*p*(UNROLL-1)
		cmp EDX,ESI
		jge forj33Rest
				
		movaps 	XMM1,[EBX+EDX]		;XMM1=baricentro[j]
		movaps 	XMM2,[EBX+EDX+p*dim]
		movaps 	XMM3,[EBX+EDX+2*p*dim]
		movaps 	XMM4,[EBX+EDX+3*p*dim]
		
		divps	XMM1,XMM7
		divps	XMM2,XMM7
		divps	XMM3,XMM7
		divps	XMM4,XMM7
		
		movaps 	[EBX+EDX],XMM1
		movaps 	[EBX+EDX+p*dim],XMM1
		movaps 	[EBX+EDX+2*p*dim],XMM1
		movaps 	[EBX+EDX+3*p*dim],XMM1
		
		add 	EDX,dim*p*UNROLL			;j++
		jmp	forj33

forj33Rest:	mov EDI,[EAX+d]
		imul ESI,EDI,dim
		cmp EDX,ESI
		jge endForJ33
				
		movaps 	XMM1,[EBX+EDX]		;XMM1=baricentro[j]
		divps	XMM1,XMM7
		movaps 	[EBX+EDX],XMM1
		
		add 	EDX,dim*p			;j++
		jmp	forj33Rest
		
endForJ33:	mov	ESI, [EBP+pesototale]
		movss	[ESI], XMM7
		; ------------------------------------------------------------
		; Sequenza di uscita dalla funzione
		; ------------------------------------------------------------

		pop	edi		; ripristina i registri da preservare
		pop	esi
		pop	ebx
		mov	esp, ebp	; ripristina lo Stack Pointer
		pop	ebp		; ripristina il Base Pointer
		ret			; torna alla funzione C chiamante	
	
	

global movimentoVolitivo

input			equ		8
indRandom		equ		12
baricentro		equ		16
molt			equ		20
i_vol			equ		24




movimentoVolitivo:
		; ------------------------------------------------------------
		; Sequenza di ingresso nella funzione
		; ------------------------------------------------------------
		push	EBP						; salva il Base Pointer
		mov	EBP, ESP					; il Base Pointer punta al Record di Attivazione corrente
		push	EBX						; salva i registri da preservare
		push	ESI
		push	EDI
		; ------------------------------------------------------------
		; legge i parametri dal Record di Attivazione corrente
		; ------------------------------------------------------------

		; elaborazione
		mov 	EAX, [EBP+input]			; EAX = &input
		movss 	XMM6, [EAX+stepvol]			; XMM6 = stepvol		
		shufps	XMM6, XMM6, 0   			; XMM6 = (stepvol| stepvol | stepvol | stepvol)
		
		movss	XMM7, [EBP+molt]
		shufps	XMM7, XMM7, 0
	
		mov 	EBX, [EAX+x]				; EBX = &x[0][0]
		mov	ECX, [EBP+i_vol]			; i
		mov 	EDX, 0					; j=0
		xorps	XMM4, XMM4				; XMM4 = distanzaEuclidea = 0;	
		
forj1:		imul 	ESI, [EAX+d], dim			; ESI = d*dim	
		sub	ESI, dim*p*(UNROLL-1)
		cmp	EDX, ESI				; (j<d*dim-dim*p*(UNROLL-1))?
		jge	forj1Rest		
		
		imul 	EDI, [EAX+d], dim			; EDI = d
		imul 	EDI, ECX				; EDI = d * i		
		add 	EDI, EDX				; EDI = d*i + j		
		
		movaps	XMM0, [EBX + EDI]			; XMM0 = x[d*i + j*p]
		movaps	XMM1, [EBX + EDI + p*dim]	
		movaps	XMM2, [EBX + EDI + 2*p*dim]	
		movaps	XMM3, [EBX + EDI + 3*p*dim]
		
		mov	ESI, [EBP+baricentro]			; ESI = &baricentro[0]
		
		subps	XMM0, [ESI+EDX]			; XMM0 = x[d*i + j*p] - baricentro[j*p]
		subps	XMM1, [ESI+EDX + p*dim]				
		subps	XMM2, [ESI+EDX + 2*p*dim]				
		subps	XMM3, [ESI+EDX + 3*p*dim]				
		
		mulps	XMM0, XMM0				; XMM0 = (x[d*i + j*p] - baricentro[j*p])^2
		mulps	XMM1, XMM1
		mulps	XMM2, XMM2
		mulps	XMM3, XMM3
		
		addps 	XMM4, XMM0				; XMM4 = distanzaEuclidea + (x[d*i + j*p] - baricentro[j*p])^2
		addps 	XMM4, XMM1
		addps 	XMM4, XMM2
		addps 	XMM4, XMM3
		
		add	EDX, dim*p*UNROLL			; j=j+p*UNROLL
		jmp	forj1
	
forj1Rest:	mov	EDI, [EAX+d]				; EDI = input->d
		imul	ESI, EDI, dim 				; ESI = d * dim 
		cmp	EDX, ESI				; (j<d*dim)?
		jge	endForj1
		
		imul 	EDI, [EAX+d], dim				; EDI = d
		imul 	EDI, ECX				; EDI = d * i		
		add 		EDI, EDX				; EDI = d*i + j
		
		movaps	XMM0, [EBX + EDI]			; XMM0 = x[d*i + j*p]	
		mov	ESI, [EBP+baricentro]			; ESI = &baricentro[0]
		movaps	XMM1, [ESI+EDX]				; XMM1 = baricentro[j*p]
		subps	XMM0, XMM1				; XMM0 = x[d*i + j*p] - baricentro[j*p]
		mulps	XMM0, XMM0				; XMM0 = (x[d*i + j*p] - baricentro[j*p])^2
		addps 	XMM4, XMM0				; XMM4 = distanzaEuclidea + (x[d*i + j*p] - baricentro[j*p])^2
		
		add	EDX, dim*p				; j=j+p
		jmp 	forj1Rest

endForj1:	haddps	XMM4, XMM4				; XMM4 = (A+B | C+D | A+B | C+D )
		haddps	XMM4, XMM4				; XMM4 = (A+B+C+D | A+B+C+D | A+B+C+D | A+B+C+D)
		sqrtps	XMM4, XMM4				; XMM4 = sqrt(distanzaEuclidea)	
		
		mov	EDI, [EBP+indRandom]			; ESI = indRandom
		add	EDI, ECX				; EDI = indRandom + i
		
		mov	ESI, [EAX+r]				; ESI = &r
		movss	XMM5, [ESI + EDI*dim]			; XMM5 = r[indRandom]
		shufps	XMM5, XMM5, 0   			; XMM5 = (r[indRandom] | r[indRandom] | r[indRandom] | r[indRandom])
		
		mov 	EDX, 0					; j=0

forj2:		imul 	ESI, [EAX+d], dim			; ESI = d*dim	
		sub	ESI, dim*p*(UNROLL-1)
		cmp	EDX, ESI				; (j<d*dim-dim*p*(UNROLL-1))?
		jge	forj2Rest		

		
		imul 	EDI, [EAX+d], dim				; EDI = d
		imul 	EDI, ECX				; EDI = d * i		
		add 		EDI, EDX				; EDI = d*i + j
		
		movaps	XMM0, [EBX + EDI]			; XMM0 = x[d*i + j*p]
		movaps	XMM1, [EBX + EDI + p*dim]	
		movaps	XMM2, [EBX + EDI + 2*p*dim]	
		movaps	XMM3, [EBX + EDI + 3*p*dim]
		
		mov	ESI, [EBP+baricentro]			; ESI = &baricentro[0]
		
		subps	XMM0, [ESI+EDX]				; XMM0 = x[d*i + j*p] - baricentro[j*p]
		subps	XMM1, [ESI+EDX + p*dim]				
		subps	XMM2, [ESI+EDX + 2*p*dim]				
		subps	XMM3, [ESI+EDX + 3*p*dim]	
		
		mulps	XMM0, XMM5				; XMM0 = r[indRandom] * (x[d*i + j*p] - baricentro[j*p])
		mulps	XMM1, XMM5				
		mulps	XMM2, XMM5				
		mulps	XMM3, XMM5				
		
		mulps	XMM0, XMM6				; XMM0 = stepvol * r[indRandom] * (x[d*i + j*p] - baricentro[j*p])
		mulps	XMM1, XMM6
		mulps	XMM2, XMM6
		mulps	XMM3, XMM6
		
		mulps	XMM0, XMM7				; XMM0 = molt * stepvol * r[indRandom] * (x[d*i + j*p] - baricentro[j*p])
		mulps	XMM1, XMM7
		mulps	XMM2, XMM7
		mulps	XMM3, XMM7

		divps	XMM0, XMM4				; XMM0 = molt * stepvol * r[indRandom] * (x[d*i + j*p] - baricentro[j*p])/distanzaEuclidea
		divps	XMM1, XMM4
		divps	XMM2, XMM4
		divps	XMM3, XMM4

		addps	XMM0, [EBX + EDI]			; XMM0 = x[d*i + j*p] + molt * stepvol * r[indRandom] * (x[d*i + j*p] - baricentro[j])/distanzaEuclidea
		addps	XMM1, [EBX + EDI + p*dim]	
		addps	XMM2, [EBX + EDI + 2*p*dim]	
		addps	XMM3, [EBX + EDI + 3*p*dim]

		movaps	[EBX + EDI], XMM0			; x[d*i + j*p] = XMM0
		movaps	[EBX + EDI + p*dim], XMM1	
		movaps	[EBX + EDI + 2*p*dim], XMM2	
		movaps	[EBX + EDI + 3*p*dim], XMM3	
		
		add	EDX, dim*p*UNROLL			; j=j+p*UNROLL
		jmp	forj2
		
forj2Rest:	mov	EDI, [EAX+d]				; EDI = input->d
		imul	ESI, EDI, dim 				; ESI = d * dim 
		cmp	EDX, ESI					; (j<d*dim)?
		jge	endForj2
		
		imul 	EDI, [EAX+d], dim				; EDI = d
		imul 	EDI, ECX				; EDI = d * i		
		add 	EDI, EDX				; EDI = d*i + j
		
		movaps	XMM0, [EBX + EDI]			; XMM0 = x[d*i + j*p]
		mov	ESI, [EBP+baricentro]			; ESI = &baricentro[0]
		subps	XMM0, [ESI+EDX]				; XMM0 = x[d*i + j*p] - baricentro[j*p]		
		mulps	XMM0, XMM5				; XMM0 = r[indRandom] * (x[d*i + j*p] - baricentro[j*p])
		mulps	XMM0, XMM6				; XMM0 = stepvol * r[indRandom] * (x[d*i + j*p] - baricentro[j*p])
		mulps	XMM0, XMM7				; XMM0 = molt * stepvol * r[indRandom] * (x[d*i + j*p] - baricentro[j*p])
		divps	XMM0, XMM4				; XMM0 = molt * stepvol * r[indRandom] * (x[d*i + j*p] - baricentro[j*p])/distanzaEuclidea
		addps	XMM0, [EBX + EDI]			; XMM0 = x[d*i + j*p] + molt * stepvol * r[indRandom] * (x[d*i + j*p] - baricentro[j])/distanzaEuclidea
		movaps	[EBX + EDI], XMM0			; x[d*i + j*p] = XMM0
		
		add	EDX, dim*p				; j=j+p
		jmp	forj2Rest
		
endForj2:	
		; ------------------------------------------------------------
		; Sequenza di uscita dalla funzione
		; ------------------------------------------------------------

		pop	ESI					; ripristina i registri da preservare
		pop	ESI
		pop	EBX
		mov	ESP, EBP				; ripristina lo Stack Pointer
		pop	EBP					; ripristina il Base Pointer
		ret						; torna alla funzione C chiamante


global func32

input		equ		8
xy		equ		12
i		equ		16
indExp		equ		20
indRis		equ		24

func32:
		; ------------------------------------------------------------
		; Sequenza di ingresso nella funzione
		; ------------------------------------------------------------
		push	EBP					; salva il Base Pointer
		mov	EBP, ESP				; il Base Pointer punta al Record di Attivazione corrente
		push	EBX					; salva i registri da preservare
		push	ESI
		push	EDI
		; ------------------------------------------------------------
		; legge i parametri dal Record di Attivazione corrente
		; ------------------------------------------------------------

		; elaborazione
		mov 	EAX, [EBP+input]			; EAX = &input
		mov	ECX, [EBP+xy]				; ECX = &xy
		mov 	ESI, [EAX + c]				; ESI = &c
		xorps	XMM0, XMM0				; esponente = 0
		xorps 	XMM7, XMM7				; cx = 0
		mov	EDX, 0					; j=0

forjf:		imul 	EBX, [EAX+d], dim			; EBX = d*dim	
		sub	EBX, dim*p*(UNROLL-1)
		cmp	EDX, EBX				; (j<d*dim-dim*p*(UNROLL-1))?
		jge	forjRestf

		imul 	EDI, [EAX+d], dim			; EDI = d*dim
		imul 	EDI, [EBP+i]				; EDI = d * dim * i 
		add 	EDI, EDX				; EDI = d*i + j
		
		movaps	XMM1, [ECX + EDI]
		movaps	XMM2, [ECX + EDI + p*dim]
		movaps	XMM3, [ECX + EDI + 2*p*dim]
		movaps	XMM4, [ECX + EDI + 3*p*dim]
		
		mulps	XMM1, XMM1
		mulps	XMM2, XMM2
		mulps	XMM3, XMM3
		mulps	XMM4, XMM4
		
		addps	XMM0, XMM1				; XMM0 = esponente + xy^2
		addps	XMM0, XMM2
		addps	XMM0, XMM3
		addps	XMM0, XMM4
		
		movaps	XMM1, [ECX + EDI]
		movaps	XMM2, [ECX + EDI + p*dim]
		movaps	XMM3, [ECX + EDI + 2*p*dim]
		movaps	XMM4, [ECX + EDI + 3*p*dim]
		
		mulps	XMM1, [ESI + EDX]			; XMM1 = c[j]*xy[d*i+j]
		mulps	XMM2, [ESI + EDX + p*dim]
		mulps	XMM3, [ESI + EDX + 2*p*dim]
		mulps	XMM4, [ESI + EDX + 3*p*dim]
		
		addps	XMM7, XMM1				; XMM2 = cx + c[j]*xy[d*i+j]
		addps	XMM7, XMM2
		addps	XMM7, XMM3
		addps	XMM7, XMM4
		
		add	EDX, dim*p*UNROLL			; j=j+p*UNROLL
		jmp	forjf
		
forjRestf:	mov	EDI, [EAX+d]				; EDI = input->d
		imul	EBX, EDI, dim 				; ESI = d * dim 
		cmp	EDX, EBX				; (j<d*dim)?
		jge	endForj
		
		imul 	EDI, [EAX+d], dim			; EDI = d*dim
		imul 	EDI, [EBP+i]				; EDI = d * dim * i 
		add 	EDI, EDX				; EDI = d*i + j
		
		movaps	XMM1, [ECX + EDI]
		mulps	XMM1, XMM1
		addps	XMM0, XMM1
		movaps	XMM1, [ECX + EDI]
		mulps	XMM1, [ESI + EDX]
		addps	XMM7, XMM1
		
		add	EDX, dim*p				; j=j+p
		jmp	forjRestf
		
endForj:	haddps	XMM0, XMM0
		haddps	XMM0, XMM0
		
		haddps	XMM7, XMM7
		haddps	XMM7, XMM7
		
		mov 	EBX, [EBP+indExp]			; EBX = &esponente	
		movss	[EBX], XMM0				
	
		subss	XMM0, XMM7				; XMM0 = esponente - cx
		mov 	EAX, [EBP + indRis]
		movss	[EAX], XMM0
		; ------------------------------------------------------------
		; Sequenza di uscita dalla funzione
		; ------------------------------------------------------------

		pop	ESI							; ripristina i registri da preservare
		pop	ESI
		pop	EBX
		mov	ESP, EBP						; ripristina lo Stack Pointer
		pop	EBP							; ripristina il Base Pointer
		ret								; torna alla funzione C chiamante
