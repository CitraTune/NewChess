import javax.swing.*;

public class Queen extends Piece{
    static ImageIcon imgQueenW = new ImageIcon("C:\\Users\\awesome22\\Downloads\\Tabler-icons_chess-queen.svg.png");
    static ImageIcon imgQueenB = new ImageIcon("C:\\Users\\awesome22\\Downloads\\Tabler-icons_chess-queen-filled.svg.png");

    public Queen(int xCor, int yCor, boolean color, String name) {
        super(xCor, yCor, color, name);

        // Queen can move diagonally, horizontally, and vertically
        for (int i = -7; i <= 7; i++) {
            if (i != 0) {
                getMovementAbs().add(new IntPair(i, i));
                getMovementAbs().add(new IntPair(i, -i));
                getMovementAbs().add(new IntPair(i, 0));
                getMovementAbs().add(new IntPair(0, i));
            }
        }
        for (int i = -7; i <= 7; i++) {
            if (i != 0) {

                if((i+xCor) <= 7 && (i + xCor) >= 0 && (i + yCor) >= 0 && (i + yCor) <= 7) {
                    getMovementRel().add(new IntPair(i + xCor, i + yCor));
                }
                if((i+xCor) <= 7 && (i + xCor) >= 0 && (-i + yCor) >= 0 && (-i + yCor) <= 7) {
                    getMovementRel().add(new IntPair(i + xCor, -i + yCor));
                }
                if((i+xCor) <= 7 && (i + xCor) >= 0) {
                    getMovementRel().add(new IntPair(i + xCor, yCor));
                }
                if((i+yCor) <= 7 && (i + yCor) >= 0) {
                    getMovementRel().add(new IntPair(xCor, i + yCor));
                }
            }
        }
        JLabel labelIcon = new JLabel();
        if (color) {
            labelIcon = new JLabel(imgSmoother(imgQueenW));
        } else if (!color) {
            labelIcon = new JLabel(imgSmoother(imgQueenB));
        }
        labelIcon.setBounds(40 +xCor*40, 40 +yCor*40, 40, 40);
        Board.filledList2D[xCor][yCor] = true;
        JLayeredPane lp = Board.mainPane;
        lp.add(labelIcon, JLayeredPane.PALETTE_LAYER);
    }

}