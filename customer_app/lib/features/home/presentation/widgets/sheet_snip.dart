          // Ride Booking Sheet
          DraggableScrollableSheet(
            initialChildSize: 0.35,
            minChildSize: 0.35,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return RideBookingSheet(scrollController: scrollController);
            },
          ),
