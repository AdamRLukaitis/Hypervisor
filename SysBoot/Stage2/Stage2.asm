;**************************************************
;
;   Stage2.asm
;       Stage2 Bootloader
;
;   Hypervisor Development
;**************************************************

bits        16

org     0x500

jmp main

;**************************************************
;   Preprocessor Directives
;**************************************************

%include    "stdio.inc"
%include    "Gdt.inc"
%include    "A20.inc"
%include    "Fat12.inc"
%include    "Common.inc"
%include    "bootinfo.inc"
%include    "memory.inc"

;**************************************************
;   Data Section
;**************************************************

LoadingMsg  db 0x0D, 0x0A, "Searching for Operating System...", 0x00
msgFailure  db 0x0D, 0x0A, "*** FATAL: Missing or corrupt KRNL32.EXE. Press Any Key to Reboot.", 0x0D, 0x0A, 0x0A, 0x00

boot_info:
istruc multiboot_info
    at multiboot_info.flags,            dd 0
    at multiboot_info.memoryLo,         dd 0
    at multiboot_info.memoryHi,         dd 0
    at multiboot_info.bootDevice,       dd 0
    at multiboot_info.cmdLine,          dd 0
    at multiboot_info.mods_count,       dd 0
    at multiboot_info.mods_addr,        dd 0
    at multiboot_info.syms0,            dd 0
    at multiboot_info.syms1,            dd 0
    at multiboot_info.syms2,            dd 0
    at multiboot_info.mmap_length,      dd 0
    at multiboot_info.mmap_addr,        dd 0
    at multiboot_info.drives_length,    dd 0
    at multiboot_info.drives_addr,      dd 0
    at multiboot_info.config_table,     dd 0
    at multiboot_info.bootloader_name,  dd 0
    at multiboot_info.apm_table,        dd 0
    at multiboot_info.vbe_control_info, dd 0
    at multiboot_info.vbe_mode_info,    dd 0
    at multiboot_info.vbe_interface_sge, dw 0
    at multiboot_info.vbe_interface_off, dw 0
    at multiboot_info.vbe_interface_len, dw 0
iend

main:

    ;---------------------------------
    ;   Setup segments and stack
    ;---------------------------------

    cli
    xor     ax, ax
    mov     ds, ax
    mov     es, ax
    mov     ax, 0x0000
    mov     ss, ax
    mov     sp, 0xFFFF
    sti

    mov     [boot_info+multiboot_info.bootDevice], dl

    call    _EnableA20
    call    InstallGDT
    sti

    xor     eax, eax
    xor     ebx, ebx
    call    BiosGetMemorySize64MB

    push    eax
    mov     eax, 64
    mul     ebx
    mov     ecx, eax
    pop     eax
    add     eax, ecx
    add     eax, 1024

    mov     dword [boot_info+multiboot_info.memoryHi], 0
    mov     dword [boot_info+multiboot_info.memoryLo], eax

    mov     eax, 0x0
    mov     ds, ex
    mov     di, 0x1000
    call    BiosGetMemoryMap

    call    LoadRoot
    mov     ebx, 0
    mov     ebp, IMAGE_RMODE_BASE
    mov     esi, ImageName
    call    LoadFile
    mov     dword [ImageSize], ecx
    cmp     ax, 0
    je      EnterStage3
    mov     si, msgFailure
    call    Puts16
    mov     ah, 0
    int     0x16
    int     0x19

    ;---------------------------------
    ;   Go into pmode
    ;---------------------------------

EnterStage3:

    cli
    mov eax, cr0
    or  eax, 1
    mov cr0, eax

    jmp CODE_DESC:Stage3

    ; Note: Do NOT re-enable interrupts! Doing so will triple fault!
    ; We will fix this in Stage 3.

;*****************************************************
;   ENTRY POINT FOR STAGE 3
;*****************************************************

bits 32

%include "Paging.inc"

BadImage db "*** FATAL: Inavlid or corrupt kernel image. Halting system.", 0

Stage3:

    ;----------------------------------
    ;   Set registers
    ;----------------------------------

    mov ax, DATA_DESC
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov esp, 90000h

    call    ClrScr32

    call    EnablePaging

CopyImage:
    mov     eax, dword [ImageSize]
    movzx   ebx, word [bpbBytesPerSector]
    mul     ebx
    mov     ebx, 4
    div     ebx
    cld
    mov     esi, IMAGE_RMODE_BASE
    mov     edi, IMAGE_RMODE_BASE
    mov     ecx, eax
    rep     movsd

TestImage:
    mov     ebx, [IMAGE_PMODE_BASE+60]
    add     ebx, IMAGE_PMODE_BASE
    mov     esi, ebx
    mov     edi, ImageSig
    cmpsw
    je      EXECUTE
    mov     ebx, BadImage
    call    Puts32
    cli
    hlt

ImageSig db 'PE'

EXECUTE:

    ;--------------------------------------
    ;   Execute Kernel
    ;--------------------------------------

    ; parse the programs header info structures to get its entry point

    add     ebx, 24
    mov     eax, [ebx]
    add     ebx, 20-4
    mov     ebp, dword[ebx]
    add     ebx, 12
    mov     eax, dword[ebx]
    add     ebp, eax
    cli

    mov     eax, 0x2badb002
    mov     ebx, 0
    mov     edx, [ImageSize]

    push    dword boot_info
    call    ebp
    add     esp, 4

    cli
    hlt

;-- header information format for PE files -----------

; typedef struct _IMAGE_DOS_HEADER {
;   USHORT e_magic;
;   USHORT e_cblp;
;   USHORT e_cp;
;   USHORT e_crlc;
;   USHORT e_cparhdr;
;   USHORT e_minalloc;
;   USHORT e_maxalloc;
;   USHORT e_ss;
;   USHORT e_sp;
;   USHORT e_csum;
;   USHORT e_ip;
;   USHORT e_cs;
;   USHORT e_lfarlc;
;   USHORT e_ovno;
;   USHORT e_res[4]
;   USHORT e_oemid;
;   USHORT e_oeminfo;
;   USHORT e_res2[10];
;   LONG    e_lfanew;
; } IAMGE_DOS_HEADER, *PIMAGE_DOS_HEADER;

;<<------------- Real mode stub program ----------->>
;<<-------------Here is the file signature, such as PE00 for NT --->>

;typedef struct _IAMGE_FILE_HEADER {
;   USHORT  Machine;
;   USHORT  NumberOfSections;
;   USHORT  TimeDateStamp;
;   USHORT  PointerToSymbolTable;
;   USHORT  NumberOfSymbols;
;   USHORT  SizeOfOptionalHeader;
;   USHORT  Characteristics;
;} IMAGE_FILE_HEADER, *PIMAGE_FILE_HEADER;

;struct _IMAGE_OPTIONAL_HEADER {
;   USHORT  Magic;
;   UCHAR   MajorLinkerVersion;
;   UCHAR   MinorLinkerVersion;
;   ULONG   SizeOfCode;
;   ULONG   SizeOfInitalizedData;
;   ULONG   SizeOfUninitializedData;
;   ULONG   AddressOfEntryPoint;
;   ULONG   BaseOfCode;
;   ULONG   BaseOfData;
;
;   ULONG   ImageBase;
;   ULONG   SectionAlignment;
;   ULONG   FileAlignment;
;   USHORT  MajorOperatingSystemVersion;
;   USHORT  MinorOperatingSystemVersion;
;   USHORT  MajorImageVersion;
;   USHORT  MinorImageVersion;
;   USHORT  MajorSubsystemVersion;
;   USHORT  MinorSubsystemVersion;
;   ULONG   Reserved1;
;   ULONG   SizeOfImage;
;   ULONG   SizeOfHeaders;
;   ULONG   CheckSum;
;   ULONG   Subsytem;
;   USHORT  DllCharacteristics;
;   ULONG   SizeOfStackReserve;
;   ULONG   SizeOfStackCommit;
;   ULONG   SizeOfHeapReserve;
;   ULONG   SizeOfHeapCommit;
;   ULONG   LoaderFlags;
;   ULONG   NumberOfRvaAndSizes;
;   IMAGE_DATA_DIRECTORY    DataDirectory[IMAGE_NUMBEROF_DIRECTORY_ENTRIES];
;} IMAGE_OPTIONAL_HEADER, *PIMAGE_OPTIONAL_HEADER;