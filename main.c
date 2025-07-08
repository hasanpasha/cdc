int main(void)
{
    int a = 50;
    int b = 20;
    if (a > 1)
        return a ? a = 1 : 2;
    else if (a > 50)
        return a;
    else
        return 2;
}