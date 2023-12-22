.386
.model flat, stdcall
option casemap:none

include windows.inc
include user32.inc
include kernel32.inc
include shell32.inc
include comctl32.inc
include gdi32.inc
include comdlg32.inc
include masm32.inc 
include advapi32.inc

includelib advapi32.lib
includelib user32.lib
includelib kernel32.lib
includelib shell32.lib
includelib comctl32.lib
includelib gdi32.lib
includelib comdlg32.lib
includelib masm32.lib
includelib msvcrt.lib


WndProc PROTO :DWORD, :DWORD, :DWORD, :DWORD

PaintBoard PROTO :DWORD, :DWORD

GenerateRandomNumberInRange PROTO :DWORD

Setup PROTO

TimerProc PROTO :DWORD, :DWORD, :DWORD, :DWORD

Random PROTO :DWORD

Block STRUCT
    x DWORD ?
    y DWORD ?
    wide DWORD ?
    height DWORD ?  
Block ENDS

Player STRUCT
    x DWORD ?
    y DWORD ?
    wide DWORD ?
    height DWORD ?
Player ENDS

IDB_Background EQU 101
IDB_Player EQU 102
IDB_Barrier EQU 103

.data

    szClassName  DB 'Pleasejump', 0
    szAppName    DB 'jumpgame', 0

    hInstance    DD ?

    hBgImageList  DD ?
    hPlayerImageList DD ?
    hBarrierImageList DD ?
    nBottomY      DD 384
    nBottomX      DD 0
    rseed         DD ?
    Barriers      Block 5 DUP (<>)
    PLAYER        Player <>
    NowBlock      Block <>
.code

WinMain PROC hInst:DWORD
    LOCAL wc:WNDCLASSEX
    LOCAL msg:MSG
    LOCAL hwnd:HWND

    mov wc.cbSize, SIZEOF WNDCLASSEX
    mov wc.style, CS_HREDRAW or CS_VREDRAW
    mov wc.lpfnWndProc, OFFSET WndProc
    push hInst
    pop wc.hInstance
    mov wc.hbrBackground, COLOR_WINDOW + 1
    mov wc.lpszClassName, OFFSET szClassName
    mov wc.lpszMenuName, NULL
    mov wc.hIcon, NULL
    mov wc.hIconSm, NULL
    mov wc.hCursor, NULL
    mov wc.cbClsExtra, NULL
    mov wc.cbWndExtra, NULL

    invoke LoadIcon, NULL, IDI_APPLICATION
    mov wc.hIcon, eax
    invoke LoadCursor, NULL, IDC_ARROW
    mov wc.hCursor, eax

    invoke RegisterClassEx, ADDR wc
    TEST eax, eax
    jz err

    invoke CreateWindowEx, NULL, OFFSET szClassName, OFFSET szAppName, \
           WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 1000, 1000, \
           NULL, NULL, hInst, NULL
    mov hwnd, eax

    invoke ShowWindow, hwnd, SW_SHOWNORMAL
    invoke UpdateWindow, hwnd

    .while TRUE
        invoke GetMessage, ADDR msg, NULL, 0, 0
        .break .if (!eax)
        invoke TranslateMessage, ADDR msg
        invoke DispatchMessage, ADDR msg
    .endw

    mov eax, msg.wParam
    ret

err:    
    invoke MessageBox, NULL, OFFSET szAppName, OFFSET szAppName, MB_ICONERROR
    invoke ExitProcess, 0

WinMain ENDP

Random proc uses ecx edx,range:DWORD
    inc rseed
	mov eax, rseed
	mov ecx, 23
	mul ecx
	add eax, 7
	and eax, 0FFFFFFFFh
	ror eax, 1
	xor eax, rseed
	mov rseed, eax
	mov ecx, range
	xor edx, edx
	div ecx
	mov eax, edx
    add eax, 200
	ret

Random endp

WndProc PROC hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
    LOCAL hdc:HDC
    LOCAL ps:PAINTSTRUCT

    .if uMsg==WM_CREATE
        invoke SetTimer, hWnd, 1, 50, NULL
        ;载入背景图片
        invoke ImageList_Create, 1000, 1000, ILC_COLOR16, 1, 0
        mov hBgImageList, eax
        invoke LoadBitmap, hInstance, IDB_Background
        invoke ImageList_AddMasked, hBgImageList, eax, 0
        invoke DeleteObject, eax
        ;载入玩家图片
        invoke ImageList_Create, 50, 100, ILC_COLOR16, 1, 0
        mov hPlayerImageList, eax
        invoke LoadBitmap, hInstance, IDB_Player
        invoke ImageList_AddMasked, hPlayerImageList, eax, 0
        invoke DeleteObject, eax
        ;载入障碍物图片
        invoke ImageList_Create, 200, 120, ILC_COLOR16, 1, 0
        mov hBarrierImageList, eax
        invoke LoadBitmap, hInstance, IDB_Barrier
        invoke ImageList_AddMasked, hBarrierImageList, eax, 0
        invoke DeleteObject, eax
        ;初始化游戏
        push ebx
        push eax
        push ecx
        push edx

        mov ebx, OFFSET Barriers
        mov ecx,50
        mov edx,800
        mov NowBlock.Block.x,ecx
        mov NowBlock.Block.y,edx
        .REPEAT
        mov [ebx].Block.x,ecx
        mov [ebx].Block.y,edx
        mov [ebx].Block.wide,200
        mov [ebx].Block.height,120
        invoke Random,100
        add ecx ,eax
        add ebx,SIZEOF Block
        .UNTIL ebx >= OFFSET Barriers + SIZEOF Barriers

        pop edx
        pop ecx
        pop eax
        pop ebx
        ;开始绘制
        invoke InvalidateRect, hWnd, NULL, TRUE
        invoke UpdateWindow, hWnd
        invoke DeleteObject, eax
    .elseif uMsg==WM_DESTROY
        invoke PostQuitMessage, 0
    .elseif uMsg==WM_PAINT
        invoke BeginPaint, hWnd, ADDR ps
        mov hdc, eax
        invoke PaintBoard, hWnd, ps.hdc
        invoke EndPaint, hWnd, ADDR ps
    .else
        invoke DefWindowProc, hWnd, uMsg, wParam, lParam
        ret
    .endif
    xor eax, eax
    ret

WndProc ENDP

PaintBoard PROC uses ebx esi edx, hWin:HWND, hDC:HDC
    LOCAL mDC:HDC
    LOCAL hBmp:DWORD
    LOCAL rect:RECT
    LOCAL wRect:RECT

    invoke CreateCompatibleDC, hDC
    mov mDC, eax
    invoke CreateCompatibleBitmap, hDC, 1000, 1000
    invoke SelectObject, mDC, eax
    push eax
    mov rect.left, 0
    mov rect.top, 0
    mov rect.right, 1000
    mov rect.bottom, 1000

    ;绘制背景
    invoke ImageList_Draw, hBgImageList, 0, mDC, 0, 0, ILD_TRANSPARENT

    ;绘制障碍物
    push ebx
    mov ebx, OFFSET Barriers
    .REPEAT
    invoke ImageList_Draw, hBarrierImageList, 0, mDC, [ebx].Block.x, [ebx].Block.y, ILD_TRANSPARENT
    add ebx,SIZEOF Block
    .UNTIL ebx >= OFFSET Barriers + SIZEOF Barriers
    pop ebx

    invoke GetClientRect, hWin, ADDR wRect
    invoke BitBlt, hDC, 0, 0, wRect.right, wRect.bottom, mDC, 0, 0, SRCCOPY

    invoke DeleteObject, eax
    invoke DeleteDC, mDC
    ret

PaintBoard ENDP

Setup proc uses ebx ecx edx eax
   
    ;初始化障碍物 
    ;push ebx
    ;push eax
    ;push ecx
    ;push edx

    ;mov ebx, OFFSET Barriers
    ;mov ecx,50
    ;mov edx,800
    ;mov NowBlock.Block.x,ecx
    ;mov NowBlock.Block.y,edx
    ;.REPEAT
    ;mov [ebx].Block.x,ecx
    ;mov [ebx].Block.y,edx
    ;mov [ebx].Block.wide,200
    ;mov [ebx].Block.height,120
    ;invoke Random,100
    ;add ecx ,eax
    ;add ebx,SIZEOF Block
    ;.UNTIL ebx >= OFFSET Barriers + SIZEOF Barriers

    ;pop edx
    ;pop ecx
    ;pop eax
    ;pop ebx

Setup ENDP

start:
    invoke GetModuleHandle, NULL
    mov [hInstance], eax
    invoke InitCommonControls
    invoke WinMain, eax
    invoke ExitProcess, 0
end start
