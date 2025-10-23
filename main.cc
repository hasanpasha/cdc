int foo(void);
static int bar(void);
int main(void)
{
    return foo() + bar();
}
static int bar(void)
{
    return 4;
}
