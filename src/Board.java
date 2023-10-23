import javax.imageio.ImageIO;
import javax.swing.*;
import java.io.IOException;
import java.util.*;
import com.google.common.collect.BiMap;
import com.google.common.collect.HashBiMap;

public class Board {
    static int intSqScale = 40;
    static int movesLeft = 1;
    static boolean turn = true; //true if it's white's turn, false if it's black's turn.
    static JButton[][] btnList2d = new JButton[8][8];
    public static BiMap<Pair<Integer, Integer>, Piece> pieceMap = HashBiMap.create();
    private static boolean pathIsBlocked(int queenX, int queenY, int targetX, int targetY, int obstacleX, int obstacleY) {
        //Returning false means that it is unblocked. Returning true means it is blocked.
        //Check if the blocking piece is in the path between the piece and the target tile
        if (obstacleY == targetY && obstacleX == targetX) {
            return false; //Target is the obstacle. Checks later if its on enemy team or not.
        }
        // Check if the blocking piece is in the path between the queen and the target tile
        if ((queenX == targetX && queenX == obstacleX) && ((obstacleY > queenY && obstacleY < targetY) || (obstacleY < queenY && obstacleY > targetY))) {
            return true; // Obstacle is in the queen's vertical path
        }
        if ((queenY == targetY && queenY == obstacleY) && ((obstacleX > queenX && obstacleX < targetX) || (obstacleX < queenX && obstacleX > targetX))) {
            return true; // Obstacle is in the queen's horizontal path
        }
        //If target is on the same diagonal as queen
        if ((Math.abs(queenX - targetX) == Math.abs(queenY - targetY))
                //If obstacle is on the same diagonal as queen
                && (Math.abs(queenX - obstacleX) == Math.abs(queenY - obstacleY))) {
            //Summarized: If all 3 are on the same diagonal
            if ((queenX < obstacleX && obstacleX < targetX) && (queenY < obstacleY && obstacleY < targetY)){
                return true; // Obstacle is in the queen's SE diagonal path
            }
            if ((queenX > obstacleX && obstacleX > targetX) && (queenY < obstacleY && obstacleY < targetY)){
                return true; // Obstacle is in the queen's SW diagonal path
            }
            if ((queenX > obstacleX && obstacleX > targetX) && (queenY > obstacleY && obstacleY > targetY)){
                return true; // Obstacle is in the queen's NW diagonal path
            }
            //BUG TO FIX. FOR SOME REASON, ON THE NE AND SW PATHS, IT JUST IGNORES BLOCKERS?
            if ((queenX < obstacleX && obstacleX < targetX) && (queenY > obstacleY && obstacleY > targetY)){
                return true; // Obstacle is in the queen's NE diagonal path
            }

        }

        return false;
    }
    private static boolean pathIsUnblockedArray(int x, int y, int xView, int yView, ArrayList<Integer> relCheckX, ArrayList<Integer> relCheckY) {
        //For every spot run every known blocker by it.
        if (relCheckX.isEmpty()){
            return true;
        }
        for (int j = 0; j < relCheckX.size(); j++) {
            //If there is ever a time when its considered blocked
            if (pathIsBlocked(x, y, xView, yView, relCheckX.get(j), relCheckY.get(j))) {
                //then it is blocked.
                //Returning false means it doesn't get added to the map.
                return false;
                //If it makes it here, it repeats. This checks for all blockers.
            }
        }
        return true;
    }
    private static boolean canMoveHere(int x, int y){
        for(int i = 0; i< lastPiece.getMovementRel().size(); i++) {
            IntPair relPair = lastPiece.getMovementRel().get(i);
            int relX = relPair.getX();
            int relY = relPair.getY();
            if (x == relX && y == relY) {
                return true;
            }
        }
    return false;
    }
    static void boardFlip(){
        //Need to take every y value, make it negative, then add 8.
        Collection<Piece> pieces = pieceMap.values();
        movesLeft++;
        if (turn) {
            // Iterate through the values and print them
            for (Piece value : pieces) {
                value.labelIcon.setBounds(intSqScale + value.xCor * intSqScale, intSqScale - ((value.yCor - 7) * intSqScale), intSqScale, intSqScale);
                for (int j = 0; j < 8; j++) {
                    for (int i = 0; i < 8; i++) {
                        btnList2d[i][j].setBounds(intSqScale + intSqScale * i, intSqScale - ((j - 7)*intSqScale), intSqScale, intSqScale);
                    }
                }
                Board.mainPane.revalidate();    // Revalidate the panel
                Board.mainPane.repaint();       // Repaint the panel
            }
            turn = false;
        }
        else {
            for (Piece value : pieces) {
                value.labelIcon.setBounds(intSqScale + value.xCor * intSqScale, intSqScale + value.yCor * intSqScale, intSqScale, intSqScale);
                for (int j = 0; j < 8; j++) {
                    for (int i = 0; i < 8; i++) {
                        btnList2d[i][j].setBounds(intSqScale + intSqScale * i, intSqScale + intSqScale * j, intSqScale, intSqScale);
                    }
                }
                Board.mainPane.revalidate();    // Revalidate the panel
                Board.mainPane.repaint();       // Repaint the panel
            }
            turn = true;
        }

    }
    static JFrame mainFrame = new JFrame();
    public static boolean moveAttempt = false;
    static ImageIcon imgBrown;
    static {
        try {
            imgBrown = new ImageIcon(ImageIO.read(images.gfras("resources/brownsquare.jpg")));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }
    static ImageIcon imgBeige;
    static {
        try {
            imgBeige = new ImageIcon(ImageIO.read(images.gfras("resources/beigesquare.png")));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }
    static ImageIcon imgRed;
    static {
        try {
            imgRed = new ImageIcon(ImageIO.read(images.gfras("resources/transquarantRed.png")));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }
    public static JLayeredPane mainPane = new JLayeredPane();
    private static Piece lastPiece;
    //This code runs when a square is clicked. It takes the x and y, stored inside that square.
    static void buttonClick(int x, int y) {
        //System.out.println(pathIsUnblocked(4, 3, 7, 0, 6, 1));
        if (!moveAttempt) {
            //Find what piece is there. This piece will be referred to as clickPiece throughout this code, no matter what type of piece it is.
            Piece clickPiece = pieceMap.get(new Pair<>(x, y));
            //Following code is when a button is clicked and if there is a piece on it. clickPiece references that piece.

            if (clickPiece != null&&clickPiece.color == turn && movesLeft>0) {
                moveAttempt = true;
                lastPiece = clickPiece;
                boolean anyMovement = false;
                //System.out.println(clickPcName);
                //These are variables that represent past coordinates of squares that do have pieces. Used to check line of sight.
                ArrayList<Integer> relCheckX = new ArrayList<>();
                ArrayList<Integer> relCheckY = new ArrayList<>();
                System.out.println(x + ", " + y);
                //Cycles through every clickPiece movement value to find blockers.
                for (int i = 0; i < clickPiece.getMovementAbs().size(); i++) {
                    //Logs all pieces that overlap with the movementAbs inside relCheck x or y.
                    //getMovementAbs gets an array of where that piece goes. get(i) shuffles through every piece in the array. getX/Y get the individual coord points.
                    //Adding x onto the end adds the current coordinate spot to the movement system which is relative to the piece. this makes it relative to the board instead of the piece.
                    int xView = clickPiece.getMovementAbs().get(i).getX() + x;
                    int yView = clickPiece.getMovementAbs().get(i).getY() + y;
                    Piece viewedPiece = pieceMap.get(new Pair<>(xView, yView));
                    if (viewedPiece != null) {
                        //Runs if the coordinate xView,yView is occupied. This means it found a piece that might change overlap or block a spot.
                        relCheckX.add(xView);
                        relCheckY.add(yView);
                        //Checks if the piece is the same color as it. Does not add the piece to the target spaces if it is.
                    }
                }
                //This code is used if there is absolutely no movement at all available.
                clickPiece.getMovementRel().clear();

                //Cycles through every movement value with line of sight blockers in mind to register which spots can and cant be moved to.
                for (int i = 0; i < clickPiece.getMovementAbs().size(); i++) {
                    int xView = clickPiece.getMovementAbs().get(i).getX() + x;
                    int yView = clickPiece.getMovementAbs().get(i).getY() + y;
                    if (xView <= 7 && xView >= 0 && yView >= 0 && yView <= 7) {
                            //If its able to go to the target without being blocked by an obstacle or if it's a knight that jumps :)
                            if (pathIsUnblockedArray(x, y, xView, yView, relCheckX, relCheckY) || (clickPiece.getClass().getName().equals("Knight"))) {
                                //If the spot we are looking at has a piece
                                if (pieceMap.get(new Pair<>(xView, yView)) != null) {
                                    //If the piece can be taken because its on the other team
                                    if (pieceMap.get(new Pair<>(xView, yView)).color != pieceMap.get(new Pair<>(x, y)).color) {
                                        //Adds it to the movement that we will paint later and reference for availability.
                                        clickPiece.getMovementRel().add(new IntPair(xView, yView));
                                        anyMovement=true;
                                    }
                                }
                                //If there is no piece at this spot.
                                else {
                                    //Adds it to the movement that we will paint later and reference for availability.
                                    clickPiece.getMovementRel().add(new IntPair(xView, yView));
                                    anyMovement=true;
                                }
                                //System.out.println("added movement to " + xView + "," + yView);
                            } else {
                                //FUTURE: possibly make units that can hop over walls use this feature. this runs just like other ones but in the else it is specifically blocked spots. one time use stuff ig.
                            }
                    }
                }
                if (!anyMovement){
                    moveAttempt= false;
                }
                clickPiece.paintRelCoords();
                relCheckX.clear();
                relCheckY.clear();
            } else {
                //Happens when clickPiece, the tile clicked, has no piece, and there is no piece trying to move right now. eventually, this should do nothing.
                System.out.println("No valid piece for movement here");
            }

        }
        else {
            //No matter what is clicked, the next button after this should be independent. (change this, this is wrong
            moveAttempt = false;
            //Also no matter what is clicked, the red squares should go away.
            lastPiece.scrapeRelCoords();
            //effectively like clickPiece from before, but now the name clarifies it might not be an actual piece.
            Piece clickTile = pieceMap.get(new Pair<>(x, y));
                //Runs if there is no piece here and if it can move here easily.
                if (clickTile == null && canMoveHere(x,y)) {
                    lastPiece.pieceMove(x, y);
                    movesLeft--;
                }
                //runs if there is a piece here. should remove the piece and then move the old piece here.
                else if (canMoveHere(x,y)){
                    assert clickTile != null;
                    clickTile.kill();
                    lastPiece.pieceMove(x, y);
                    movesLeft--;
                }
        }
    }
    public Board() {

        mainFrame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        javax.swing.ToolTipManager.sharedInstance().setInitialDelay(20);
        images.makeIconTransparent(imgRed);

        for (int j = 0; j < 8; j++) {
            for (int i = 0; i < 8; i++) {
                if ((j % 2 == 0) && (i % 2 == 0)) {
                    //This code creates a margin with the intsqscales that aren't multiplied and are just added
                    //With the ones multiplied by two, those act as alternating colored squares.
                    //The if else statements check what row they are on, and alternates between margins to accommodate
                    final int index = i;
                    final int indey = j;
                    btnList2d[i][j] = new JButton(imgBeige);
                    btnList2d[i][j].setBounds(intSqScale + intSqScale * i, intSqScale + intSqScale * j, intSqScale, intSqScale);
                    btnList2d[i][j].setBorderPainted(false);
                    btnList2d[i][j].addActionListener(e -> buttonClick(index,indey));
                    mainPane.add(btnList2d[i][j], JLayeredPane.DEFAULT_LAYER);
                } else if ((j % 2 != 0) && (i % 2 != 0)) {
                    //These are just slightly modified versions of the first one.
                    final int index = i;
                    final int indey = j;
                    btnList2d[i][j] = new JButton(imgBeige);
                    btnList2d[i][j].setBounds(intSqScale + intSqScale * i, intSqScale + intSqScale * j, intSqScale, intSqScale);
                    btnList2d[i][j].setBorderPainted(false);
                    btnList2d[i][j].addActionListener(e -> buttonClick(index,indey));
                    mainPane.add(btnList2d[i][j], JLayeredPane.DEFAULT_LAYER);
                }
                else if (j % 2 == 0) {
                    final int index = i;
                    final int indey = j;
                    btnList2d[i][j] = new JButton(imgBrown);
                    btnList2d[i][j].setBounds(intSqScale + intSqScale * i, intSqScale + intSqScale * j, intSqScale, intSqScale);
                    btnList2d[i][j].setBorderPainted(false);
                    btnList2d[i][j].addActionListener(e -> buttonClick(index,indey));
                    mainPane.add(btnList2d[i][j], JLayeredPane.DEFAULT_LAYER);
                } else {
                    final int index = i;
                    final int indey = j;
                    btnList2d[i][j] = new JButton(imgBrown);
                    btnList2d[i][j].setBounds(intSqScale + intSqScale * i, intSqScale + intSqScale * j, intSqScale, intSqScale);
                    btnList2d[i][j].setBorderPainted(false);
                    btnList2d[i][j].addActionListener(e -> buttonClick(index,indey));
                    mainPane.add(btnList2d[i][j], JLayeredPane.DEFAULT_LAYER);
                }
                btnList2d[i][j].setToolTipText((i) + "," + (j));
            }
        }
        mainFrame.setSize(600, 600);
        mainFrame.getContentPane().add(mainPane);
        mainFrame.setVisible(true);
        //CREATING THE PIECES
        ArrayList<Pawn> pawnListW = new ArrayList<>();
        ArrayList<Pawn> pawnListB = new ArrayList<>();
        for(int i = 0; i < 8; i++){
            //This loop create the 8 pawns at rows 2 and 7
            pawnListW.add(new Pawn(i, 6, true, "pawnListW" +i));
            pawnListB.add(new Pawn(i, 1, false, "pawnListB" +i));

        }
        Rook rookW1 = new Rook(0, 7, true, "rookW1");
        Rook rookW2 = new Rook(7, 7, true, "rookW2");
        Knight knightW1 = new Knight(1, 7, true, "knightW1");
        Knight knightW2 = new Knight(6, 7, true, "knightW2");
        Bishop bishopW1 = new Bishop(2, 7, true, "bishopW1");
        Bishop bishopW2 = new Bishop(5, 7, true, "bishopW2");
        King kingW = new King(4, 7, true, "kingW");
        Queen queenW = new Queen(3, 7, true, "queenW");
        Rook rookB1 = new Rook(0, 0, false, "rookB1");
        Rook rookB2 = new Rook(7, 0, false, "rookB2");
        Knight knightB1 = new Knight(1, 0, false, "knightB1");
        Knight knightB2 = new Knight(6, 0, false, "knightB2");
        Bishop bishopB1 = new Bishop(2, 0, false, "bishopB1");
        Bishop bishopB2 = new Bishop(5, 0, false, "bishopB2");
        King kingB = new King(4, 0, false, "kingB");
        Queen queenB = new Queen(3, 0, false, "queenB");
    }
}
