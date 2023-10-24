import javax.swing.*;

public class EndTurn {
    static JButton something = new JButton("end turn");
    public static void glow(){
        something.setText("end turn!!");
    }
    public static void unglow(){
        something.setText("end turn");
    }


    public EndTurn(){
        something.setBounds(400,100,100,50);
        something.setBorderPainted(false);
        something.addActionListener(e -> Board.boardFlip());
        Board.mainPane.add(something, JLayeredPane.DEFAULT_LAYER);


    }
}

