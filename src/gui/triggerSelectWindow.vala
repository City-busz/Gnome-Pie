/////////////////////////////////////////////////////////////////////////
// Copyright (c) 2011-2015 by Simon Schneegans
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
/////////////////////////////////////////////////////////////////////////

namespace GnomePie {

/////////////////////////////////////////////////////////////////////////
/// This window allows the selection of a hotkey. It is returned in form
/// of a Trigger. Therefore it can be either a keyboard driven hotkey or
/// a mouse based hotkey.
/////////////////////////////////////////////////////////////////////////

public class TriggerSelectWindow : GLib.Object {

    /////////////////////////////////////////////////////////////////////
    /// This signal is emitted when the user selects a new hot key.
    /////////////////////////////////////////////////////////////////////

    public signal void on_ok(Trigger trigger);

    /////////////////////////////////////////////////////////////////////
    /// Some private members which are needed by other methods.
    /////////////////////////////////////////////////////////////////////

    private Gtk.Dialog window;
    private Gtk.CheckButton turbo;
    private Gtk.CheckButton delayed;
    private Gtk.CheckButton centered;
    private Gtk.CheckButton warp;
    private Gtk.RadioButton rshape[10];
    private TriggerSelectButton button;

    /////////////////////////////////////////////////////////////////////
    /// The currently configured trigger.
    /////////////////////////////////////////////////////////////////////

    private Trigger trigger = null;

    /////////////////////////////////////////////////////////////////////
    /// The trigger which was active when this window was opened. It is
    /// stored in order to check whether anything has changed when the
    /// user clicks on OK.
    /////////////////////////////////////////////////////////////////////

    private Trigger original_trigger = null;

    /////////////////////////////////////////////////////////////////////
    /// Radioboxes call toggled() twice per selection change.
    /// This flag is used to discard one of the two notifications.
    /////////////////////////////////////////////////////////////////////

    private static int notify_toggle= 0;

    /////////////////////////////////////////////////////////////////////
    /// C'tor, constructs a new TriggerSelectWindow.
    /////////////////////////////////////////////////////////////////////

    public TriggerSelectWindow() {
        try {

            Gtk.Builder builder = new Gtk.Builder();

            builder.add_from_file (Paths.ui_files + "/trigger_select.ui");

            this.window = builder.get_object("window") as Gtk.Dialog;
            this.button = new TriggerSelectButton(true);
            this.button.show();

            this.button.on_select.connect((trigger) => {
                this.trigger = new Trigger.from_values(trigger.key_sym,
                                                       trigger.modifiers,
                                                       trigger.with_mouse,
                                                       this.turbo.active,
                                                       this.delayed.active,
                                                       this.centered.active,
                                                       this.warp.active,
                                                       this.get_radio_shape());
            });

            (builder.get_object("trigger-box") as Gtk.Box).pack_start(this.button, true, true);

            (builder.get_object("ok-button") as Gtk.Button).clicked.connect(this.on_ok_button_clicked);
            (builder.get_object("cancel-button") as Gtk.Button).clicked.connect(this.on_cancel_button_clicked);

            this.turbo = builder.get_object("turbo-check") as Gtk.CheckButton;
            this.turbo.toggled.connect(this.on_check_toggled);

            this.delayed = builder.get_object("delay-check") as Gtk.CheckButton;
            this.delayed.toggled.connect(this.on_check_toggled);

            this.centered = builder.get_object("center-check") as Gtk.CheckButton;
            this.centered.toggled.connect(this.on_check_toggled);

            this.warp = builder.get_object("warp-check") as Gtk.CheckButton;
            this.warp.toggled.connect(this.on_check_toggled);

            for (int i= 0; i < 10; i++) {
                this.rshape[i] = builder.get_object("rshape%d".printf(i)) as Gtk.RadioButton;
                this.rshape[i].toggled.connect(this.on_radio_toggled);
            }

            this.window.delete_event.connect(this.window.hide_on_delete);

        } catch (GLib.Error e) {
            error("Could not load UI: %s\n", e.message);
        }
    }

    /////////////////////////////////////////////////////////////////////
    /// Sets the parent window, in order to make this window stay in
    /// front.
    /////////////////////////////////////////////////////////////////////

    public void set_parent(Gtk.Window parent) {
        this.window.set_transient_for(parent);
    }

    /////////////////////////////////////////////////////////////////////
    /// Displays the window on the screen.
    /////////////////////////////////////////////////////////////////////

    public void show() {
        this.window.show_all();
    }

    /////////////////////////////////////////////////////////////////////
    /// Initilizes all members to match the Trigger of the Pie with the
    /// given ID.
    /////////////////////////////////////////////////////////////////////

    public void set_pie(string id) {
        var trigger = new Trigger.from_string(PieManager.get_accelerator_of(id));

        this.turbo.active = trigger.turbo;
        this.delayed.active = trigger.delayed;
        this.centered.active = trigger.centered;
        this.warp.active = trigger.warp;
        this.set_radio_shape( trigger.shape );
        this.original_trigger = trigger;
        this.trigger = trigger;

        this.button.set_trigger(trigger);
    }

    /////////////////////////////////////////////////////////////////////
    /// Called when one of the checkboxes is toggled.
    /////////////////////////////////////////////////////////////////////

    private void on_check_toggled() {
        if (this.trigger != null)
            this.trigger = new Trigger.from_values(this.trigger.key_sym, this.trigger.modifiers,
                                                   this.trigger.with_mouse, this.turbo.active,
                                                   this.delayed.active, this.centered.active,
                                                   this.warp.active,
                                                   this.get_radio_shape());
    }

    /////////////////////////////////////////////////////////////////////
    /// Returns the current selected radio-button shape: 0= automatic
    /// 5= full pie; 1,3,7,8= quarters; 2,4,6,8=halves
    /// 1 | 4 | 7
    /// 2 | 5 | 8
    /// 3 | 6 | 9
    /////////////////////////////////////////////////////////////////////

    private int get_radio_shape() {
        int rs;
        for (rs= 0; rs < 10; rs++)
            if (this.rshape[rs].active)
                break;
        return rs;
    }

    /////////////////////////////////////////////////////////////////////
    /// Sets the current selected radio-button shape: 0= automatic
    /// 5= full pie; 1,3,7,8= quarters; 2,4,6,8=halves
    /////////////////////////////////////////////////////////////////////

    private void set_radio_shape(int rs) {
        if (rs < 0 || rs > 9)
            rs= 5;  //replace invalid value with default= full pie
        this.rshape[rs].active= true;
    }

    /////////////////////////////////////////////////////////////////////
    /// Called twice when one of the radioboxes is toggled.
    /////////////////////////////////////////////////////////////////////

    private void on_radio_toggled() {
        notify_toggle= 1 - notify_toggle;
        if (notify_toggle == 1)
            on_check_toggled(); //just call once
    }

    /////////////////////////////////////////////////////////////////////
    /// Called when the OK-button is pressed.
    /////////////////////////////////////////////////////////////////////

    private void on_ok_button_clicked() {
        var assigned_id = PieManager.get_assigned_id(this.trigger);

        if (this.trigger == this.original_trigger) {
            // nothing did change
            this.window.hide();
        } else if (this.trigger.key_code == this.original_trigger.key_code
                && this.trigger.modifiers == this.original_trigger.modifiers
                && this.trigger.with_mouse == this.original_trigger.with_mouse) {
            // only turbo and/or delayed mode changed, no need to check for double assignment
            this.on_ok(this.trigger);
            this.window.hide();
        } else if (assigned_id != "") {
            // it's already assigned
            var error = _("This hotkey is already assigned to the pie \"%s\"! \n\nPlease select " +
                          "another one or cancel your selection.").printf(PieManager.get_name_of(assigned_id));
            var dialog = new Gtk.MessageDialog((Gtk.Window)this.window.get_toplevel(), Gtk.DialogFlags.MODAL,
                                               Gtk.MessageType.ERROR, Gtk.ButtonsType.CANCEL, error);
            dialog.run();
            dialog.destroy();
        } else {
            // a unused hot key has been chosen, great!
            this.on_ok(this.trigger);
            this.window.hide();
        }
    }

    /////////////////////////////////////////////////////////////////////
    /// Called when the cancel button is pressed.
    /////////////////////////////////////////////////////////////////////

    private void on_cancel_button_clicked() {
        this.window.hide();
    }
}

}
