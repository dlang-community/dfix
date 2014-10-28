pure nothrow void doStuff(int x[]) {
	try
		whatever();
	catch
		somethingElse();
	asm
	{
		mov sp[EBP], ESP;
		inc _iSemlockCtrs[EDX * 2];
	}
}

int someMapping[string];

void* pointers[];

enum a = "a";
enum someString = "123"
"456";

alias x y;

template Tst(string s) { enum Tst = s; }
alias Tst!"Test" Mod;
alias Tst!"Test2" Mod2;

alias immutable(int) IInt;

alias LRESULT function (HWND, UINT, WPARAM, LPARAM) WNDPROC;
alias UINT function (HWND, UINT, WPARAM, LPARAM) LPOFNHOOKPROC;
alias EXCEPTION_DISPOSITION function (
	EXCEPTION_RECORD *exceptionRecord,
	DEstablisherFrame *frame,
	CONTEXT *context,
	void *dispatcherContext) LanguageSpecificHandler;
private extern (D) alias void function (Object) fp_t;

alias static immutable(OpInfo) Opcode;
alias extern (C) void function() EntryFn;

alias __vector(T) Vector;


alias extern(C) RT function(P) nothrow @nogc __externC;

private alias extern(C) int function(dl_phdr_info*, size_t, void*) __dl_iterate_hdr_callback;
alias extern(C) void function() externCVoidFunc;
alias void delegate(void*, void*) nothrow ScanAllThreadsFn; /// The scanning function.
alias void delegate(ScanType, void*, void*) nothrow ScanAllThreadsTypeFn; /// ditto
alias void* function() gcGetFn;
