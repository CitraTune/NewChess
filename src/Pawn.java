import javax.imageio.ImageIO;
import javax.swing.*;
import java.io.IOException;

class Pawn extends Piece{

    static ImageIcon imgPawnW;
    static {
        try {
            imgPawnW = new ImageIcon(ImageIO.read(images.gfras("resources/Tabler-icons_chess.svg.png")));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }
    static ImageIcon imgPawnB;
    static {
        try {
            imgPawnB = new ImageIcon(ImageIO.read(images.gfras("resources/Tabler-icons_chess-filled.svg.png")));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }
    public void pawnAtkCheck(){
        int xP = xCor+1;
        int xN = xCor-1;
        int yP = yCor+1;
        int yN = yCor-1;
        if (!color){
            if (Board.pieceMap.get(new Pair<>(xP,yP)) != null && Board.pieceMap.get(new Pair<>(xP,yP)).color != color){
                getMovementRel().add(new IntPair(xP, yP));
            }
            else if (Board.pieceMap.get(new Pair<>(xN,yP)) != null && Board.pieceMap.get(new Pair<>(xN,yP)).color != color){
                getMovementRel().add(new IntPair(xN, yP));
            }}
        else {
            if (Board.pieceMap.get(new Pair<>(xP,yN)) != null && Board.pieceMap.get(new Pair<>(xP,yN)).color != color){
                getMovementRel().add(new IntPair(xP, yN));
            }
            else if (Board.pieceMap.get(new Pair<>(xN,yN)) != null && Board.pieceMap.get(new Pair<>(xN,yN)).color != color){
                getMovementRel().add(new IntPair(xN, yN));
            }
        }
    }



    public Pawn(int xCor, int yCor, boolean color, String name) {
        super(xCor, yCor, color, name);
        if (!color) {
            //Need method that puts the object name first, syntax says pawnW1.getMovement and this is equivalent to the ArrayList of the movement possibilities (Absolute)
            getMoveOnlyAbs().add(new IntPair(0, 1));
            getMoveOnlyAbs().add(new IntPair(0, 2));
        }
        else{
            getMoveOnlyAbs().add(new IntPair(0, -1));
            getMoveOnlyAbs().add(new IntPair(0, -2));
        }
        movedYet = false;

        //Add system that removes the part from movementAbs when the movement that moves 2 up is selected


        //Make these checks run everytime the button it is on is clicked.


        moveOnly = true;
        if (color) {
            labelIcon = new JLabel(imgSmoother(imgPawnW));
        } else {
            labelIcon = new JLabel(imgSmoother(imgPawnB));
        }
        labelIcon.setBounds(40 +xCor*40, 40 +yCor*40, 40, 40);
        Board.mainPane.add(labelIcon, JLayeredPane.PALETTE_LAYER);
    }

}