typedef struct Node {
    int value;
    struct Node *next;
} Node;

int list_sum(Node *head) {
    int sum = 0;
    while (head != 0) {
        sum += head->value;
        head = head->next;
    }
    return sum;
}
