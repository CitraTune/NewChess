import javax.swing.*;

public class Rook extends Piece{
    static ImageIcon imgRookW = new ImageIcon("C:\\Users\\awesome22\\Downloads\\Tabler-icons_chess-rook.svg.png");
    static ImageIcon imgRookB = new ImageIcon("C:\\Users\\awesome22\\Downloads\\Tabler-icons_chess-rook-filled.svg.png");


    //Objectname.PaintRelCoords()



    public void newPosition(){
        getMovementRel().clear();
    }




    public Rook(int xCor, int yCor, boolean color, String name) {
        super(xCor, yCor, color, name);

        // Rook can move horizontally and vertically
        for (int i = -7; i <= 7; i++) {
            if (i != 0) {
                getMovementAbs().add(new IntPair(i, 0));
                getMovementAbs().add(new IntPair(0, i));

            }
        }

        for (int i = -7; i <= 7; i++) {
            if (i != 0) {
                if((i+xCor) <= 7 && (i + xCor) >= 0) {
                    getMovementRel().add(new IntPair(i + xCor, yCor));
                }
                if((i+yCor) <= 7 && (i + yCor) >= 0) {
                    getMovementRel().add(new IntPair(xCor, i + yCor));
                }

            }
        }
        //How to access the object itself when running the declaration. I need the map to know the xCor and yCor of the object.

        JLabel labelIcon = new JLabel();
        if (color) {
            labelIcon = new JLabel(imgSmoother(imgRookW));
        } else if (!color) {
            labelIcon = new JLabel(imgSmoother(imgRookB));
        }
        labelIcon.setBounds(40 +xCor*40, 40 +yCor*40, 40, 40);
        Board.filledList2D[xCor][yCor] = true;
        JLayeredPane lp = Board.mainPane;
        lp.add(labelIcon, JLayeredPane.PALETTE_LAYER);
    }

}