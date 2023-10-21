import javax.swing.*;
import java.awt.*;
import java.util.ArrayList;
import java.util.List;

public class Piece {


    static ImageIcon imgSmoother(ImageIcon largeimg){

        Image image = largeimg.getImage(); // transform it
        Image newimg = image.getScaledInstance(40, 40,  java.awt.Image.SCALE_SMOOTH); // scale it the smooth way
        largeimg = new ImageIcon(newimg);
        return(largeimg);
    }

    int xCor;
    int yCor;
    boolean color;
    String name;
    JLabel labelIcon = new JLabel();
    private List<IntPair> movementAbs = new ArrayList<>();
    private List<IntPair> movementRel = new ArrayList<>();
    public void paintRelCoords() {
        for (int i = 0; i < getMovementRel().size(); i++ ){
            IntPair relPair = getMovementRel().get(i);
            int relX = relPair.getX();
            int relY = relPair.getY();
            JLabel tranPane = new JLabel(imgSmoother(Board.imgRed));
            //Put in multiple if statements to prevent the program from continuing
            //Check if space is occupied in piecemap. Check if space contains a piece. Prevent further
            //checks if it contains a piece. If the piece is an enemy piece, include it.
            //Check if it is on the board: Do this by checking each square and seeing if relX
            tranPane.setBounds(40 + relX * 40, 40 + relY * 40, 40, 40);
            JLayeredPane lp = Board.mainPane;
            lp.add(tranPane, JLayeredPane.PALETTE_LAYER);

        }
    }

    public void scrapeRelCoords() {
        for (int i = 0; i < getMovementRel().size(); i++ ){
            IntPair relPair = getMovementRel().get(i);
            int relX = relPair.getX();
            int relY = relPair.getY();
            JLabel tranPane = new JLabel(imgSmoother(Board.imgRed));
            //Put in multiple if statements to prevent the program from continuing
            //Check if space is occupied in piecemap. Check if space contains a piece. Prevent further
            //checks if it contains a piece. If the piece is an enemy piece, include it.
            //Check if it is on the board: Do this by checking each square and seeing if relX
            tranPane.setBounds(40 + relX * 40, 40 + relY * 40, 40, 40);

            JLayeredPane lp = Board.mainPane;
            lp.add(tranPane, JLayeredPane.PALETTE_LAYER);

        }
    }


    //True = white, false = black

    public void pieceMove (int xCorNew, int yCorNew){
        //Changes filledList2d the array and make xCorOld and yCorOld be false, then make the xCorNew and yCorNew be true.
        //Changes the object on that square.
        this.setxCor(xCorNew);
        this.setyCor(yCorNew);
        Board.pieceMap.forcePut(new Pair<>(xCorNew, yCorNew), this);
        labelIcon.setBounds(40 +xCor*40, 40 +yCor*40, 40, 40);
        //Board.mainPane.add(labelIcon, JLayeredPane.PALETTE_LAYER);
    }

    public int getxCor() {
        return xCor;
    }

    public void setxCor(int xCor) {
        this.xCor = xCor;
    }

    public int getyCor() {
        return yCor;
    }

    public void setyCor(int yCor) {
        this.yCor = yCor;
    }

    public Piece(int xCor, int yCor, boolean color, String name) {
        List<IntPair> movementAbs = new ArrayList<>();
        this.xCor = xCor;
        this.yCor = yCor;
        this.color = color;
        this.name = name;
        Board.pieceMap.put(new Pair<>(xCor, yCor), this);
    }

    public List<IntPair> getMovementAbs() {
        return movementAbs;
    }

    public void setMovementAbs(List<IntPair> movementAbs) {
        this.movementAbs = movementAbs;
    }

    public List<IntPair> getMovementRel() {
        return movementRel;
    }

    public void setMovementRel(List<IntPair> movementRel) {
        this.movementRel = movementRel;
    }
//        JLabel labelIcon = new JLabel(imgSmoother(pieceIcon));
//        labelIcon.setBounds(xCor*40, yCor*40, 40, 40);
//        JLayeredPane lp = Board.drawPane;
//        lp.add(labelIcon, JLayeredPane.PALETTE_LAYER);



}
