public class Pair<K1, K2> {
    private final K1 key1;
    private final K2 key2;

    public Pair(K1 key1, K2 key2) {
        this.key1 = key1;
        this.key2 = key2;
    }

    @Override
    public int hashCode() {
        return key1.hashCode() ^ key2.hashCode();
    }

    @Override
    public boolean equals(Object obj) {
        if (this == obj) {
            return true;
        }
        if (obj == null || getClass() != obj.getClass()) {
            return false;
        }
        Pair<?, ?> pair = (Pair<?, ?>) obj;
        return key1.equals(pair.key1) && key2.equals(pair.key2);
    }
}