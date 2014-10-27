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
