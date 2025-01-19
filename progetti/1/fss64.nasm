; ---------------------------------------------------------
; Regression con istruzioni AVX a 64 bit
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
;     nasm -f elf64 regression64.nasm
;

%include "sseutils64.nasm"

section .data			; Sezione contenente dati inizializzati
	align 32
	uno 			dq 		1.0,1.0,1.0,1.0
	align 32
	due 			dq 		2.0,2.0,2.0,2.0
	align 32
	zero 			dq 		0.0,0.0,0.0,0.0
	align 32
	menoUno		dq		-1.0,-1.0,-1.0,-1.0
	msg db 'prova',0
	nl db 10,0

section .bss			; Sezione contenente dati non inizializzati
ris resq 1
ris2 resq 4

section .text			; Sezione contenente il codice macchina
x				equ		0
xh				equ		8
c				equ		16
r				equ		24
np				equ		32
d				equ		36
iter				equ		40
stepind				equ		48
stepvol				equ		56
wscale				equ		64

dim 				equ		8
p 				equ		4
UNROLL 			equ		4
; Sezione contenente il codice macchina

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
	mov	rdi, %1
	mov	rsi, %2
	call	get_block
%endmacro

%macro	fremem	1
	mov	rdi, %1
	call	free_block
%endmacro


global movimentoIndividuale1:


movimentoIndividuale1:
		; ------------------------------------------------------------
		; Sequenza di ingresso nella funzione
		; ------------------------------------------------------------
		push		rbp				; salva il Base Pointer
		mov		rbp, rsp			; il Base Pointer punta al Record di Attivazione corrente
		pushaq		
		; ------------------------------------------------------------
		; legge i parametri dal Record di Attivazione corrente
		; ------------------------------------------------------------
		;RDI=input
		;RSI=indRandom*
		;RDX=matrixy
		;RCX=zeri
		
		
		
		MOV R15d, [RSI]
		MOV R14d, [RDI+np]
		MOV R13d, [RDI+d]
		MOV R12, R13
		SUB R12, p*UNROLL
		MOV RBX, R13
		SUB RBX, RCX
		MOV R11, [RDI+r]
		MOV R10, [RDI+x]
		
		VMOVSD XMM15, [RDI+stepind]; YMM15=stepind
		vbroadcastsd  YMM15, XMM15
		
		
		VMOVAPD YMM14, [due]
		
		VMOVAPD YMM13, [uno]
		
		XOR R8,R8; i=0
		
		
loopi:	CMP R8,R14; i<np
		JGE endloopi
		XOR R9,R9; j=0
loopj:	CMP R9,R12;j<d-16; 
		JGE loopzeri
		
		;---CASO J<D-4
		VMOVUPD YMM0, [R11+R15*dim]
		VMOVUPD YMM1, [R11+R15*dim+1*p*dim]
		VMOVUPD YMM2, [R11+R15*dim+2*p*dim]
		VMOVUPD YMM3, [R11+R15*dim+3*p*dim]
		
		VMULPD YMM0, YMM14
		VMULPD YMM1, YMM14
		VMULPD YMM2, YMM14
		VMULPD YMM3, YMM14
		
		VSUBPD YMM0,YMM13
		VSUBPD YMM1,YMM13
		VSUBPD YMM2,YMM13
		VSUBPD YMM3,YMM13
				
		VMULPD YMM0,YMM15; YMM0 =(2 * R[IndRandom]  - 1) * stepind
		VMULPD YMM1,YMM15 
		VMULPD YMM2,YMM15
		VMULPD YMM3,YMM15
		
		MOV RAX,R8; R11=i;
		IMUL RAX,R13; R11=i*d
		ADD RAX,R9; R11=i*d+j
	
		; YMM4 =X[I*D+J] VETTORIZZATO
		VMOVAPD YMM4, [R10+RAX*dim]
		VMOVAPD YMM5, [R10+RAX*dim+1*p*dim]
		VMOVAPD YMM6, [R10+RAX*dim+2*p*dim]
		VMOVAPD YMM7, [R10+RAX*dim+3*p*dim]
		
		VADDPD YMM0,YMM4
		VADDPD YMM1,YMM5
		VADDPD YMM2,YMM6
		VADDPD YMM3,YMM7

		VMOVAPD  [RDX+RAX*dim], YMM0
		VMOVAPD  [RDX+RAX*dim+1*p*dim], YMM1
		VMOVAPD  [RDX+RAX*dim+2*p*dim], YMM2
		VMOVAPD  [RDX+RAX*dim+3*p*dim], YMM3
		
		
		ADD R15,p*UNROLL
		JMP next
	
loopzeri:	CMP R9,RBX;j<d-zeri; 
		JGE jpadding
		VMOVSD XMM0, [R11+R15*dim]
		VMULSD XMM0, XMM14
		VSUBSD XMM0, XMM13
		VMULSD XMM0, XMM15
		
		MOV RAX,R8; RAX=i;
		IMUL RAX,R13;RAX=i*d
		ADD RAX,R9;RAX=i*d+j
		
		VMOVSD XMM1,[R10+RAX*dim]
		VADDSD XMM0,XMM1
		VMOVSD [RDX+RAX*dim],XMM0

		INC R15
		JMP nextpadd

jpadding:	VMOVSD XMM0,[zero]
		MOV RAX,R8; RAX=i;
		IMUL RAX,R13;RAX=i*d
		ADD RAX,R9;RAX=i*d+j
		VMOVSD [RDX+RAX*dim],XMM0
nextpadd: INC R9
		CMP R9,R13
		JGE endloopj
		JMP loopzeri

next:	ADD R9,p*UNROLL
		JMP loopj

endloopj:	INC R8
		JMP loopi
		
		; ------------------------------------------------------------
		; Sequenza di uscita dalla funzione
		; ------------------------------------------------------------

endloopi:	MOV [RSI],R15d
		popaq				; ripristina i registri generali
		mov		rsp, rbp	; ripristina lo Stack Pointer
		pop		rbp		; ripristina il Base Pointer
		ret			; torna alla funzione C chiamante




global movimentoIndividuale2:

movimentoIndividuale2:
		;------------------------------------------------------------
		;Sequenza di ingresso nella funzione
		;------------------------------------------------------------
		push		rbp				; salva il Base Pointer
		mov		rbp, rsp			; il Base Pointer punta al Record di Attivazione corrente
		pushaq	
		;------------------------------------------------------------
		;legge i parametri dal Record di Attivazione corrente
		;------------------------------------------------------------
		;RDI=input
		;RSI=ymatrix
		;RDX=deltaX
		;RCX=deltaF
		

		MOV R8, 0
		
		MOV R15d,[RDI+np]
		MOV R14d,[RDI+d]
		MOV R13,R14
		SUB R13, p*UNROLL
		
		MOV R10, [RDI+x]
		
		VMOVAPD YMM8, [zero] 
		
fori:		CMP R8,R15; I<NP?
		JGE endfori
		XOR R9,R9
		MOV RAX, [RCX+R8*dim]; RAX=DELTAF[I]
		CMP RAX, 0
		JGE else
		
forj:		CMP R9,R13
		JGE forresto
		MOV RBX,R8
		IMUL RBX,R14
		ADD RBX,R9
		
		VMOVAPD YMM0, [RSI+RBX*dim]
		VMOVAPD YMM1, [RSI+RBX*dim+1*p*dim]
		VMOVAPD YMM2, [RSI+RBX*dim+2*p*dim]
		VMOVAPD YMM3, [RSI+RBX*dim+3*p*dim]
		
		VMOVAPD YMM4, [R10+RBX*dim]
		VMOVAPD YMM5, [R10+RBX*dim+1*p*dim]
		VMOVAPD YMM6, [R10+RBX*dim+2*p*dim]
		VMOVAPD YMM7, [R10+RBX*dim+3*p*dim]
		
		VMOVAPD  [R10+RBX*dim], YMM0
		VMOVAPD  [R10+RBX*dim+1*p*dim], YMM1
		VMOVAPD  [R10+RBX*dim+2*p*dim], YMM2
		VMOVAPD  [R10+RBX*dim+3*p*dim], YMM3
		
		VSUBPD YMM0,YMM4
		VSUBPD YMM1,YMM5
		VSUBPD YMM2,YMM6
		VSUBPD YMM3,YMM7
				
		VMOVAPD [RDX+RBX*dim],YMM0
		VMOVAPD [RDX+RBX*dim+1*p*dim],YMM1
		VMOVAPD [RDX+RBX*dim+2*p*dim],YMM2
		VMOVAPD [RDX+RBX*dim+3*p*dim],YMM3
		ADD R9,p*UNROLL
		JMP forj
		
forresto:	CMP R9,R14
		JGE endforj
		MOV RBX,R8
		IMUL RBX,R14
		ADD RBX,R9
		
		VMOVSD XMM0, [RSI+RBX*dim]
		VMOVSD XMM1, [R10+RBX*dim]
		VMOVSD [R10+RBX*dim],XMM0
		VSUBSD XMM0,XMM1
		VMOVSD [RDX+RBX*dim],XMM0
		
		INC R9
		JMP forresto		
		
else:		VMOVSD [RCX+R8*dim],XMM8
loopje:	CMP R9,R13
		JGE loopjer
		MOV RBX,R8
		IMUL RBX,R14
		ADD RBX,R9
		
		VMOVAPD [RDX+RBX*dim],YMM8
		VMOVAPD [RDX+RBX*dim+1*UNROLL*dim],YMM8
		VMOVAPD [RDX+RBX*dim+2*UNROLL*dim],YMM8
		VMOVAPD [RDX+RBX*dim+3*UNROLL*dim],YMM8
		ADD R9, p*UNROLL
		JMP loopje
		
loopjer:	CMP R9,R14
		JGE endforj
		MOV RBX,R8
		IMUL RBX,R14
		ADD RBX,R9
		VMOVSD [RDX+RBX*dim],XMM8
		INC R9 
		JMP loopjer
		
endforj:	INC R8
		JMP fori	
		;------------------------------------------------------------
		;Sequenza di uscita dalla funzione
		;------------------------------------------------------------

endfori:	popaq				; ripristina i registri generali
		mov		rsp, rbp	; ripristina lo Stack Pointer
		pop		rbp		; ripristina il Base Pointer
		ret			; torna alla funzione C chiamante


global operatoreAlimentazione:
		;RDI=input
		;RSI=pesi
		;RDX=deltaF
		;RCX=min

operatoreAlimentazione:
		;------------------------------------------------------------
		;Sequenza di ingresso nella funzione
		;------------------------------------------------------------
		push		rbp				; salva il Base Pointer
		mov		rbp, rsp			; il Base Pointer punta al Record di Attivazione corrente
		pushaq		
		;------------------------------------------------------------
		;legge i parametri dal Record di Attivazione corrente
		;------------------------------------------------------------
		
		MOV R15D, [RDI+np]
		MOV R14,R15
		SUB R14,p*UNROLL
		VMOVSD XMM15, XMM0
		vbroadcastsd  YMM15, XMM15
		
		XOR R8,R8
		
aggiorna:	CMP R8,R14
		JGE loopr
		
		VMOVAPD YMM0,[RDX+R8*dim]
		VMOVAPD YMM1,[RDX+R8*dim+1*UNROLL*dim]
		VMOVAPD YMM2,[RDX+R8*dim+2*UNROLL*dim]
		VMOVAPD YMM3,[RDX+R8*dim+3*UNROLL*dim]
		
		VDIVPD YMM0,YMM15
		VDIVPD YMM1,YMM15
		VDIVPD YMM2,YMM15
		VDIVPD YMM3,YMM15
		
		VMOVAPD YMM4,[RSI+R8*dim]
		VMOVAPD YMM5,[RSI+R8*dim+1*UNROLL*dim]
		VMOVAPD YMM6,[RSI+R8*dim+2*UNROLL*dim]
		VMOVAPD YMM7,[RSI+R8*dim+3*UNROLL*dim]
		
		VADDPD YMM0,YMM4
		VADDPD YMM1,YMM5
		VADDPD YMM2,YMM6
		VADDPD YMM3,YMM7
		
		VMOVAPD [RSI+R8*dim],YMM0
		VMOVAPD [RSI+R8*dim+1*UNROLL*dim],YMM1
		VMOVAPD [RSI+R8*dim+2*UNROLL*dim],YMM2
		VMOVAPD [RSI+R8*dim+3*UNROLL*dim],YMM3
		
		ADD R8,p*UNROLL
		JMP aggiorna
		
loopr:	CMP R8,R15
		JGE fine
		VMOVSD XMM0,[RDX+R8*dim]
		VDIVSD XMM0,XMM15
		VMOVSD XMM1,[RSI+R8*dim]
		VADDSD XMM0,XMM1
		VMOVSD [RSI+R8*dim],XMM0
		INC R8
		JMP loopr	
		;------------------------------------------------------------
		;Sequenza di uscita dalla funzione
		;------------------------------------------------------------
fine:		popaq				; ripristina i registri generali
		mov		rsp, rbp	; ripristina lo Stack Pointer
		pop		rbp		; ripristina il Base Pointer
		ret			; torna alla funzione C chiamante
		
global movimentoIstintivo

;RDI=input
;RSI=I

movimentoIstintivo:
		; ------------------------------------------------------------
		; Sequenza di ingresso nella funzione
		; ------------------------------------------------------------
		push		rbp				; salva il Base Pointer
		mov		rbp, rsp			; il Base Pointer punta al Record di Attivazione corrente
		pushaq						; salva i registri generali
		
		mov RAX, [RDI + x] 			;RAX = &x
		mov R15D,[RDI + np]
		mov R14D,[RDI + d]
		mov R13,R14
		sub R13, p*UNROLL-1
		xor R8,R8				;i=0

foris:		cmp R8,R15 				
		jge endforis
		xor R9,R9

forjs:	 	cmp R9,R13 				;(j<d*dim-dim*p*(UNROLL-1))?
		jge forjsRest

		mov R10,R8
		imul R10,R14
		add R10,R9

		vmovapd YMM0, [RAX + R10*dim]
		vmovapd YMM1, [RAX + R10*dim+p*dim]
		vmovapd YMM2, [RAX + R10*dim+2*p*dim]
		vmovapd YMM3, [RAX + R10*dim+3*p*dim]

		vmovapd YMM4, [RSI + R9*dim] 			;YMM5=I[j]
		vmovapd YMM5, [RSI + R9*dim+p*dim]
		vmovapd YMM6, [RSI + R9*dim+2*p*dim]
		vmovapd YMM7, [RSI + R9*dim+3*p*dim]

		vaddpd YMM0, YMM4
		vaddpd YMM1, YMM5
		vaddpd YMM2, YMM6
		vaddpd YMM3, YMM7

		vmovapd [RAX + R10*dim],YMM0
		vmovapd [RAX + R10*dim+ p*dim],YMM1
		vmovapd [RAX + R10*dim+ 2*p*dim],YMM2
		vmovapd [RAX + R10*dim+ 3*p*dim],YMM3

		add R9, p*UNROLL 				;j=j+p*UNROLL
		jmp forjs


forjsRest:	cmp R9, R14 					;(j<d)?
		jge endForjs

		mov R10,R8
		imul R10,R14
		add R10,R9

		vmovapd YMM0, [RAX + R10*dim]

		vmovapd YMM1,[RSI + R9*dim] 			;I[j]=YMM5

		vaddpd YMM0,YMM1

		vmovapd [RAX+R10*dim],YMM0

		add R9, p 					;j=j+p
		jmp forjsRest

endForjs:
		inc R8
		jmp foris


		; ------------------------------------------------------------
		; Sequenza di uscita dalla funzione
		; ------------------------------------------------------------



endforis:	popaq 		; ripristina i registri generali
		mov rsp, rbp 	; ripristina lo Stack Pointer
		pop rbp 	; ripristina il Base Pointer
		ret 		; torna alla funzione C chiamante
		
		
global calcolaI

; RDI=input
; RSI=deltaF
; RDX=deltaX
; RCX=I

calcolaI:
		; ------------------------------------------------------------
		; Sequenza di ingresso nella funzione
		; ------------------------------------------------------------
		push		rbp				; salva il Base Pointer
		mov		rbp, rsp			; il Base Pointer punta al Record di Attivazione corrente
		pushaq						; salva i registri generali

		mov R15D,[RDI + np]
		mov R14D,[RDI + d]
		mov R13,R14
		sub R13, p*UNROLL-1
		
		vxorpd XMM7,XMM7
		
		xor R9,R9				;j=0
		
			
forj21:		cmp R9,R13 				;(j<d-p*(UNROLL-1))?
		jge forj21Rest	

		
		vxorpd 	YMM1,YMM1		;I[j]=0
		vxorpd 	YMM2,YMM2
		vxorpd 	YMM3,YMM3
		vxorpd 	YMM4,YMM4
		
		vmovapd	[RCX+R9*dim],YMM1
		vmovapd	[RCX+R9*dim+p*dim],YMM2
		vmovapd [RCX+R9*dim+2*p*dim],YMM3
		vmovapd [RCX+R9*dim+3*p*dim],YMM4
		
		add 	R9,p*UNROLL	;j++
		jmp	forj21

forj21Rest:	cmp R9, R14 					;j<d?
		jge endForJ21				
		
		vxorpd 	YMM1,YMM1
		
		vmovapd [RCX+R9*dim],YMM1
		
		add 	R9,p					;j++
		jmp	forj21Rest

		
endForJ21:	xor R8,R8		;i=0
		

fori2:		cmp R8,R15 				
		jge endFori2
		xor R9,R9 		 	;j=0
		
		vmovsd 	XMM5,[RSI+R8*dim]		;XMM5=deltaF[i]
		
		
		vaddsd 	XMM7,XMM5		;somma+=deltaF[i]
		vbroadcastsd  YMM5, XMM5
		
forj22:		cmp R9,R13 
		jge forj22Rest
		
		mov R10,R8
		imul R10,R14
		add R10,R9			;EDI = d*i +j
		 	
		vmovapd YMM0,[RDX+R10*dim]		;YMM0=deltaX[d*i+j]
		vmovapd YMM1,[RDX+R10*dim+p*dim]
		vmovapd YMM3,[RDX+R10*dim+2*p*dim]
		vmovapd YMM4,[RDX+R10*dim+3*p*dim]
		
		
		vmulpd 	YMM0,YMM5		;deltaX[d*i+j]*deltaF[i]
		vmulpd	YMM1,YMM5
		vmulpd	YMM3,YMM5
		vmulpd	YMM4,YMM5
		
		
		vaddpd	YMM0,[RCX+R9*dim]		;I[j]+deltaX[d*i+j]*deltaF[i]
		vaddpd	YMM1,[RCX+R9*dim+p*dim]
		vaddpd	YMM3,[RCX+R9*dim+2*p*dim]
		vaddpd	YMM4,[RCX+R9*dim+3*p*dim]
		
		vmovapd	[RCX+R9*dim],YMM0
		vmovapd	[RCX+R9*dim+p*dim],YMM1
		vmovapd	[RCX+R9*dim+p*2*dim],YMM3
		vmovapd [RCX+R9*dim+p*3*dim],YMM4
		
		add R9,p*UNROLL
		jmp forj22
		
forj22Rest:	cmp R9, R14
		jge endForJ22
			
		mov R10,R8
		imul R10,R14
		add R10,R9		;EDI = d*i +j
		 	
		vmovapd YMM0,[RDX+R10*dim]		;XMM0=deltaX[d*i+j]
		
		
		vmulpd 	YMM0,YMM5			;deltaX[d*i+j]*deltaF[i]
		vaddpd	YMM0,[RCX+R9*dim]		;I[j]+deltaX[d*i+j]*deltaF[i]
		
		vmovapd [RCX+R9*dim],YMM0
		
		add R9,p
		jmp forj22Rest		
		
endForJ22:	inc R8
		jmp fori2
		
		
endFori2:	xor R9,R9			;j=0
        	vbroadcastsd  YMM7, XMM7
        	
        	mov 	R8,0
		vmovsd 	[ris],XMM7
		mov 	R15,[ris]
		cmp	R15,R8
		JE	endForJ23
        	
forj23:		cmp R9, R13
		jge forj23Rest
				
		vmovapd YMM0,[RCX+R9*dim]		;XMM1=I[j]
		vmovapd	YMM1,[RCX+R9*dim+p*dim]	
		vmovapd	YMM3,[RCX+R9*dim+2*p*dim]
		vmovapd	YMM4,[RCX+R9*dim+3*p*dim]
		
		vdivpd	YMM0,YMM7
		vdivpd	YMM1,YMM7
		vdivpd	YMM3,YMM7
		vdivpd	YMM4,YMM7
		
		vmovapd	[RCX+R9*dim],YMM0
		vmovapd	[RCX+R9*dim+p*dim],YMM1
		vmovapd [RCX+R9*dim+2*p*dim],YMM3
		vmovapd	[RCX+R9*dim+3*p*dim],YMM4

		add R9,p*UNROLL		;j++
		jmp	forj23
		
forj23Rest:	cmp R9, R14
		jge endForJ23	

		vmovapd YMM0,[RCX+R9*dim]		;XMM1=I[j]
	
		vdivpd	YMM0,YMM7
		
		vmovapd	[RCX+R9*dim],YMM0
		
		add R9,p		;j++		
		jmp	forj23Rest		


endForJ23:

		; ------------------------------------------------------------
		; Sequenza di uscita dalla funzione
		; ------------------------------------------------------------



		popaq 		; ripristina i registri generali
		mov rsp, rbp 	; ripristina lo Stack Pointer
		pop rbp 	; ripristina il Base Pointer
		ret 		; torna alla funzione C chiamante
		
global calcolaBaricentro

;RDI=input
;RSI=baricentro
;RDX=indPesoTotale
;RCX=pesi


calcolaBaricentro:
		; ------------------------------------------------------------
		; Sequenza di ingresso nella funzione
		; ------------------------------------------------------------
		push		rbp				; salva il Base Pointer
		mov		rbp, rsp			; il Base Pointer punta al Record di Attivazione corrente
		pushaq						; salva i registri generali

		
		
		
		mov RAX, [RDI + x] 			;RAX = &x
		mov R15D,[RDI + np]
		mov R14D,[RDI + d]
		mov R13,R14
		sub R13, p*UNROLL-1
		
		vxorpd XMM7,XMM7
		
		xor R9,R9				;j=0
			
forj31:		cmp R9,R13 				;(j<d-p*(UNROLL-1))?
		jge forj31Rest	

		vxorpd 	YMM1,YMM1		;baricentro[j]=0
		
		vmovapd	[RSI+R9*dim],YMM1
		vmovapd	[RSI+R9*dim+p*dim],YMM1
		vmovapd [RSI+R9*dim+2*p*dim],YMM1
		vmovapd [RSI+R9*dim+3*p*dim],YMM1
		
		add 	R9,p*UNROLL	;j++
		jmp	forj31

forj31Rest:	cmp R9, R14 					;(j<d*dim)?
		jge endForJ31				
		
		vxorpd 	YMM1,YMM1		
		vmovapd [RSI+R9*dim],YMM1
		
		add 	R9,p					;j++
		jmp	forj31Rest
		
endForJ31:	xor R8,R8		;i=0
		
fori3:		cmp R8,R15 				
		jge endFori3
		xor R9,R9 		 	;j=0
		
		vmovsd 	XMM5,[RCX+R8*dim]		;XMM5=pesi[i]
		
		vaddsd 	XMM7,XMM5		;pesototale+=pesi[i]
		vbroadcastsd  YMM5, XMM5
		
forj32:		cmp R9,R13 
		jge forj32Rest
		
		mov R10,R8
		imul R10,R14
		add R10,R9			;EDI = d*i +j
		 	
		vmovapd YMM0,[RAX+R10*dim]		;YMM0= X[d*i+j]
		vmovapd YMM1,[RAX+R10*dim+p*dim]
		vmovapd YMM3,[RAX+R10*dim+2*p*dim]
		vmovapd YMM4,[RAX+R10*dim+3*p*dim]
		
		
		vmulpd 	YMM0,YMM5		;X[d*i+j]*pesi[i]
		vmulpd	YMM1,YMM5
		vmulpd	YMM3,YMM5
		vmulpd	YMM4,YMM5
		
		
		vaddpd	YMM0,[RSI+R9*dim]		;baricentro[j]+X[d*i+j]*pesi[i]
		vaddpd	YMM1,[RSI+R9*dim+p*dim]
		vaddpd	YMM3,[RSI+R9*dim+2*p*dim]
		vaddpd	YMM4,[RSI+R9*dim+3*p*dim]
		
		vmovapd	[RSI+R9*dim],YMM0
		vmovapd	[RSI+R9*dim+p*dim],YMM1
		vmovapd	[RSI+R9*dim+p*2*dim],YMM3
		vmovapd [RSI+R9*dim+p*3*dim],YMM4
		
		add R9,p*UNROLL
		jmp forj32
		
forj32Rest:	cmp R9, R14
		jge endForJ32
			
		mov R10,R8
		imul R10,R14
		add R10,R9		;EDI = d*i +j
		 	
		vmovapd YMM0,[RAX+R10*dim]		;YMM0=X[d*i+j]	
		vmulpd 	YMM0,YMM5			;X[d*i+j]*pesi[i]
		vaddpd	YMM0,[RSI+R9*dim]		;baricentro[j]+X[d*i+j]*pesi[i]
		vmovapd [RSI+R9*dim],YMM0
		
		add R9,p
		jmp forj32Rest		
		
endForJ32:	inc R8
		jmp fori3
		
		
endFori3:	xor R9,R9			;j=0
        	vbroadcastsd  YMM7, XMM7 
		
forj33:		cmp R9, R13
		jge forj33Rest
				
		vmovapd YMM0,[RSI+R9*dim]		;YMM0=baricentro[j]
		vmovapd	YMM1,[RSI+R9*dim+p*dim]	
		vmovapd	YMM3,[RSI+R9*dim+2*p*dim]
		vmovapd	YMM4,[RSI+R9*dim+3*p*dim]
		
		vdivpd	YMM0,YMM7
		vdivpd	YMM1,YMM7
		vdivpd	YMM3,YMM7
		vdivpd	YMM4,YMM7
		
		vmovapd	[RSI+R9*dim],YMM0
		vmovapd	[RSI+R9*dim+p*dim],YMM1
		vmovapd [RSI+R9*dim+2*p*dim],YMM3
		vmovapd	[RSI+R9*dim+3*p*dim],YMM4

		add R9,p*UNROLL		;j++
		jmp	forj33
		
forj33Rest:	cmp R9, R14
		jge endForJ33	

		vmovapd YMM0,[RSI+R9*dim]		;YMM0=baricentro[j]
		vdivpd	YMM0,YMM7
		vmovapd	[RSI+R9*dim],YMM0
		
		add 	R9,p		;j++		
		jmp	forj33Rest		


endForJ33:	vmovsd	[RDX], XMM7

		; ------------------------------------------------------------
		; Sequenza di uscita dalla funzione
		; ------------------------------------------------------------
		popaq 		; ripristina i registri generali
		mov rsp, rbp 	; ripristina lo Stack Pointer
		pop rbp 	; ripristina il Base Pointer
		ret 		; torna alla funzione C chiamante
		
		
global movimentoVolitivo

;RDI=input
;RSI=indRandom
;RDX=baricentro
;RCX=indPesoTotale
;R8=indNuovoPesoTotale

movimentoVolitivo:
		; ------------------------------------------------------------
		; Sequenza di ingresso nella funzione
		; ------------------------------------------------------------
		push		rbp				; salva il Base Pointer
		mov		rbp, rsp			; il Base Pointer punta al Record di Attivazione corrente
		pushaq						; salva i registri generali

		; elaborazione
		vmovsd 		XMM6, [RDI+stepvol]			; XMM6 = stepvol		
		vbroadcastsd  	YMM6, XMM6				; YMM6 = (stepvol| stepvol | stepvol | stepvol)
		
		
		mov		R13D, [RSI]				; R13 = indRandom
		mov		R14, [RDI+r]				; ESI = &r
		mov		R15D, [RDI+np]				; R15 = input->np
		mov 		RBX, [RDI+x]				; RBX = &x[0][0]
		
		vmovapd		YMM7, [uno]				; YMM7 = molt = 1
		
		mov		RAX, [R8]				; EAX = indNuovoPesoTotale	
		cmp		RAX, [RCX]				; (nuovoPesoTotale>pesoTotale)?
		jle		avanti
		vmovapd		YMM7, [menoUno]				; XMM5 = molt = -1	
avanti:		mov		R10, 0					; i=0
		imul 		EAX, [RDI+d], dim			; EAX = d*dim
		mov		R9, RAX
		sub		R9, dim*p*(UNROLL-1)

forif:		mov 		R11, 0					; j=0
		vxorpd		YMM4, YMM4, YMM4			; YMM4 = distanzaEuclidea = 0;
	
forj1:		cmp		R11, R9					; (j<d*dim-dim*p*(UNROLL-1))?
		jge		forj1Rest		
		
		mov 		R12, RAX				; R12 = d * dim
		imul 		R12, R10				; R12 = d * i		
		add 		R12, R11				; R12 = d*i + j
		
		vmovapd		YMM0, [RBX + R12]			; YMM0 = x[d*i + j*p]
		vmovapd		YMM1, [RBX + R12 + p*dim]	
		vmovapd		YMM2, [RBX + R12 + 2*p*dim]	
		vmovapd		YMM3, [RBX + R12 + 3*p*dim]	
		
		vsubpd		YMM0, [RDX + R11]			; YMM0 = x[d*i + j*p] - baricentro[j*p]
		vsubpd		YMM1, [RDX + R11 + p*dim]				
		vsubpd		YMM2, [RDX + R11 + 2*p*dim]				
		vsubpd		YMM3, [RDX + R11 + 3*p*dim]				
		
		vmulpd		YMM0, YMM0				; YMM0 = (x[d*i + j*p] - baricentro[j*p])^2
		vmulpd		YMM1, YMM1
		vmulpd		YMM2, YMM2
		vmulpd		YMM3, YMM3
		
		vaddpd 		YMM4, YMM0				; XMM4 = distanzaEuclidea + (x[d*i + j*p] - baricentro[j*p])^2
		vaddpd 		YMM4, YMM1
		vaddpd 		YMM4, YMM2
		vaddpd 		YMM4, YMM3
		
		add		R11, dim*p*UNROLL			; j=j+p*UNROLL
		jmp		forj1
	
forj1Rest:	cmp		R11, RAX				; (j<d*dim)?
		jge		endForj1

		mov 		R12, RAX				; R12 = d * dim
		imul 		R12, R10				; R12 = d * i		
		add 		R12, R11				; R12 = d*i + j
		
		vmovapd		YMM0, [RBX + R12]			; YMM0 = x[d*i + j*p]	
		vsubpd		YMM0, [RDX + R11]			; YMM0 = x[d*i + j*p] - baricentro[j*p]
		vmulpd		YMM0, YMM0				; YMM0 = (x[d*i + j*p] - baricentro[j*p])^2
		vaddpd 		YMM4, YMM0				; XMM4 = distanzaEuclidea + (x[d*i + j*p] - baricentro[j*p])^2
		
		add		R11, dim*p				; j=j+p
		jmp 		forj1Rest

endForj1:	vhaddpd		YMM4, YMM4				
		vperm2f128	YMM5, YMM4, YMM4, 00010001b
		vaddpd		YMM4, YMM5
		vsqrtpd		YMM4, YMM4				; YMM4 = sqrt(distanzaEuclidea)	

		vmovsd		XMM5, [R14 + R13*dim]			; XMM5 = r[indRandom]
		vbroadcastsd  	YMM5, XMM5				; YMM5 = (r[indRandom] | r[indRandom] | r[indRandom] | r[indRandom])
		
		
		mov 		R11, 0					; j=0
forj2:		cmp		R11, R9					; (j<d*dim-dim*p*(UNROLL-1))?
		jge		forj2Rest		

		mov 		R12, RAX				; R12 = d * dim
		imul 		R12, R10				; R12 = d * i		
		add 		R12, R11				; R12 = d*i + j
		
		vmovapd		YMM0, [RBX + R12]			; YMM0 = x[d*i + j*p]
		vmovapd		YMM1, [RBX + R12 + p*dim]	
		vmovapd		YMM2, [RBX + R12 + 2*p*dim]	
		vmovapd		YMM3, [RBX + R12 + 3*p*dim]
		
		vsubpd		YMM0, [RDX + R11]			; YMM0 = x[d*i + j*p] - baricentro[j*p]
		vsubpd		YMM1, [RDX + R11 + p*dim]				
		vsubpd		YMM2, [RDX + R11 + 2*p*dim]				
		vsubpd		YMM3, [RDX + R11 + 3*p*dim]	
		
		vmulpd		YMM0, YMM5				; YMM0 = r[indRandom] * (x[d*i + j*p] - baricentro[j*p])
		vmulpd		YMM1, YMM5				
		vmulpd		YMM2, YMM5				
		vmulpd		YMM3, YMM5				
		
		vmulpd		YMM0, YMM6				; YMM0 = stepvol * r[indRandom] * (x[d*i + j*p] - baricentro[j*p])
		vmulpd		YMM1, YMM6				
		vmulpd		YMM2, YMM6				
		vmulpd		YMM3, YMM6
		
		vmulpd		YMM0, YMM7				; YMM0 = molt * stepvol * r[indRandom] * (x[d*i + j*p] - baricentro[j*p])
		vmulpd		YMM1, YMM7				
		vmulpd		YMM2, YMM7				
		vmulpd		YMM3, YMM7

		vdivpd		YMM0, YMM4				; YMM0 = molt * stepvol * r[indRandom] * (x[d*i + j*p] - baricentro[j*p])/distanzaEuclidea
		vdivpd		YMM1, YMM4
		vdivpd		YMM2, YMM4
		vdivpd		YMM3, YMM4

		vaddpd		YMM0, [RBX + R12]			; YMM0 = x[d*i + j*p] + molt * stepvol * r[indRandom] * (x[d*i + j*p] - baricentro[j])/distanzaEuclidea
		vaddpd		YMM1, [RBX + R12 + p*dim]	
		vaddpd		YMM2, [RBX + R12 + 2*p*dim]	
		vaddpd		YMM3, [RBX + R12 + 3*p*dim]

		vmovapd		[RBX + R12], YMM0			; x[d*i + j*p] = YMM0
		vmovapd		[RBX + R12 + p*dim], YMM1	
		vmovapd		[RBX + R12 + 2*p*dim], YMM2	
		vmovapd		[RBX + R12 + 3*p*dim], YMM3	
		
		add		R11, dim*p*UNROLL			; j=j+p*UNROLL
		jmp		forj2
		
forj2Rest:	cmp		R11, RAX					; (j<d*dim)?
		jge		endForj2
	
		mov 		R12, RAX				; R12 = d * dim
		imul 		R12, R10				; R12 = d * i		
		add 		R12, R11				; R12 = d*i + j
		
		vmovapd		YMM0, [RBX + R12]			; YMM0 = x[d*i + j*p]
		vsubpd		YMM0, [RDX + R11]			; YMM0 = x[d*i + j*p] - baricentro[j*p]	
		vmulpd		YMM0, YMM5				; YMM0 = r[indRandom] * (x[d*i + j*p] - baricentro[j*p])
		vmulpd		YMM0, YMM6				; YMM0 = stepvol * r[indRandom] * (x[d*i + j*p] - baricentro[j*p])
		vmulpd		YMM0, YMM7				; YMM0 = molt * stepvol * r[indRandom] * (x[d*i + j*p] - baricentro[j*p])
		vdivpd		YMM0, YMM4				; YMM0 = molt * stepvol * r[indRandom] * (x[d*i + j*p] - baricentro[j*p])/distanzaEuclidea
		vaddpd		YMM0, [RBX + R12]			; YMM0 = x[d*i + j*p] + molt * stepvol * r[indRandom] * (x[d*i + j*p] - baricentro[j])/distanzaEuclidea
		vmovapd		[RBX + R12], YMM0			; x[d*i + j*p] = YMM0
		
		add		R11, dim*p				; j=j+p
		jmp		forj2Rest
		
endForj2:	inc		R13					; indRandom++
		inc		R10					; i++
		cmp		R10, R15				; (i<np*dim)?
		jb		forif
		
		mov		[RSI], R13D				; *indRandom = indRandom
		vmovsd		XMM0, [R8]				; XMM0 = nuovoPesoTotale
		vmovsd 		[RCX], XMM0				; pesoTotale = nuovoPesoTotale
		
		; ------------------------------------------------------------
		; Sequenza di uscita dalla funzione
		; ------------------------------------------------------------
		popaq				; ripristina i registri generali
		mov		rsp, rbp	; ripristina lo Stack Pointer
		pop		rbp		; ripristina il Base Pointer
		ret				; torna alla funzione C chiamante









global func64


;RDI=input
;RSI=xy
;RDX=i
;RCX=indExp
;R8=indRis


func64:
		; ------------------------------------------------------------
		; Sequenza di ingresso nella funzione
		; ------------------------------------------------------------
		push		rbp				; salva il Base Pointer
		mov		rbp, rsp			; il Base Pointer punta al Record di Attivazione corrente
		pushaq						; salva i registri generali
	
		mov 	RAX, [RDI + c]				; RAX = &c
		vxorpd	YMM0, YMM0, YMM0			; esponente = 0
		vxorpd	YMM7, YMM7, YMM7			; cx = 0
		
		imul 	R10D, [RDI+d], dim 			; R10D = d*dim
		mov 	R9, R10					; R9 = d*dim	
		sub	R9, dim*p*(UNROLL-1)
		mov	RBX, 0					; j=0

forjf:		cmp	RBX, R9					; (j<d*dim-dim*p*(UNROLL-1))?
		jge	forjRest
		
		mov	R11, R10
		imul 	R11, RDX				; R11 = d * dim * i 
		add 	R11, RBX				; R11 = d*i + j
		
		vmovapd	YMM1, [RSI + R11]
		vmovapd	YMM2, [RSI + R11 + p*dim]
		vmovapd	YMM3, [RSI + R11 + 2*p*dim]
		vmovapd	YMM4, [RSI + R11 + 3*p*dim]

		vmulpd	YMM5, YMM1, YMM1
		vmulpd	YMM6, YMM2, YMM2
		vmulpd	YMM8, YMM3, YMM3
		vmulpd	YMM9, YMM4, YMM4
		
		vaddpd	YMM0, YMM5				; YMM0 = esponente + xy^2
		vaddpd	YMM0, YMM6
		vaddpd	YMM0, YMM8
		vaddpd	YMM0, YMM9
		
		vmulpd	YMM1, [RAX + RBX]			; YMM1 = c[j]*xy[d*i+j]
		vmulpd	YMM2, [RAX + RBX + p*dim]
		vmulpd	YMM3, [RAX + RBX + 2*p*dim]
		vmulpd	YMM4, [RAX + RBX + 3*p*dim]
		
		vaddpd	YMM7, YMM1			
		vaddpd	YMM7, YMM2
		vaddpd	YMM7, YMM3
		vaddpd	YMM7, YMM4

		add	RBX, dim*p*UNROLL			; j=j+p*UNROLL
		jmp	forjf
		
forjRest:	cmp	RBX, R10				; (j<d*dim)?
		jge	endForj
		
		mov	R11, R10				
		imul 	R11, RDX				; R11 = d * dim * i 
		add 	R11, RBX				; R11 = d*i + j
		
		vmovapd	YMM1, [RSI + R11]
		vmulpd	YMM5, YMM1, YMM1
		vaddpd	YMM0, YMM5
		vmulpd	YMM1, [RAX + RBX]	
		vaddpd	YMM7, YMM1
		
		add	RBX, dim*p				; j=j+p
		jmp	forjRest
		
endForj:	vhaddpd		YMM0, YMM0, YMM0
		vperm2f128	YMM1, YMM0, YMM0, 00010001b	
		vaddpd		YMM1, YMM0
		
		vhaddpd		YMM7, YMM7, YMM7
		vperm2f128	YMM2, YMM7, YMM7, 00010001b	
		vaddpd		YMM2, YMM7
						
		vmovsd	[RCX], XMM1				
	
		vsubsd	XMM1, XMM2				; YMM1 = esponente - cx
		vmovsd	[R8], XMM1

		; ------------------------------------------------------------
		; Sequenza di uscita dalla funzione
		; ------------------------------------------------------------
		popaq				; ripristina i registri generali
		mov		rsp, rbp	; ripristina lo Stack Pointer
		pop		rbp		; ripristina il Base Pointer
		ret				; torna alla funzione C chiamante
		
		
