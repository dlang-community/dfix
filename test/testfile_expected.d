pure nothrow void doStuff(int[] x) {
	try
		whatever();
	catch (Throwable)
		somethingElse();
	asm
	{
		mov sp[EBP], ESP;
		inc _iSemlockCtrs[EDX * 2];
	}
}

int[string] someMapping;

void*[] pointers;

enum a = "a";
enum someString = "123"
~ "456";

alias y = x;

template Tst(string s) { enum Tst = s; }
alias Mod = Tst!"Test";
alias Mod2 = Tst!"Test2";

alias IInt = immutable(int);

alias WNDPROC = LRESULT function (HWND, UINT, WPARAM, LPARAM);
alias LPOFNHOOKPROC = UINT function (HWND, UINT, WPARAM, LPARAM);
alias LanguageSpecificHandler = EXCEPTION_DISPOSITION function (
	EXCEPTION_RECORD *exceptionRecord,
	DEstablisherFrame *frame,
	CONTEXT *context,
	void *dispatcherContext);
private extern (D) alias fp_t = void function (Object);

alias Opcode = static immutable(OpInfo);
alias EntryFn = extern (C) void function();

alias Vector = __vector(T);


alias __externC = extern(C) RT function(P) nothrow @nogc;

private alias __dl_iterate_hdr_callback = extern(C) int function(dl_phdr_info*, size_t, void*);
alias externCVoidFunc = extern(C) void function();
alias ScanAllThreadsFn = void delegate(void*, void*) nothrow; /// The scanning function.
alias ScanAllThreadsTypeFn = void delegate(ScanType, void*, void*) nothrow; /// ditto
alias gcGetFn = void* function();

alias PCONTEXT = CONTEXT*, LPCONTEXT = CONTEXT*;
alias PEXCEPTION_RECORD = EXCEPTION_RECORD*, LPEXCEPTION_RECORD = EXCEPTION_RECORD*;
alias PEXCEPTION_POINTERS = EXCEPTION_POINTERS*, LPEXCEPTION_POINTERS = EXCEPTION_POINTERS*;
