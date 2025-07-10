int main(void) {
    int x = 10;
    if (0)
    {
    label:
    {
        int x = 5;
        {
            int y = x + 10;
            return y;
        }
    }
    }
    goto label;
    return 0;
}